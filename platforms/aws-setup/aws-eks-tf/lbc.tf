# --------------------------------------------------------------------------------------------------
# lbc.tf - AWS Load Balancer Controller Configuration
# --------------------------------------------------------------------------------------------------

# Create an IAM OIDC Identity Provider for the cluster
resource "aws_iam_oidc_provider" "eks_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.k8s_goat_cluster.identity[0].oidc[0].issuer
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.k8s_goat_cluster.identity[0].oidc[0].issuer
}

# IAM Policy for the AWS Load Balancer Controller
resource "aws_iam_policy" "lbc_policy" {
  name        = "${var.cluster_name}-lbc-policy"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

# IAM Role for the AWS Load Balancer Controller Service Account
resource "aws_iam_role" "lbc_role" {
  name = "${var.cluster_name}-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_oidc_provider.eks_oidc_provider.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_oidc_provider.eks_oidc_provider.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lbc_policy_attachment" {
  policy_arn = aws_iam_policy.lbc_policy.arn
  role       = aws_iam_role.lbc_role.name
}

# Install the AWS Load Balancer Controller using the Helm chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.4.8" # Use a specific version for consistency

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc_role.arn
  }

  depends_on = [
    aws_eks_node_group.k8s_goat_node_group,
    aws_iam_role_policy_attachment.lbc_policy_attachment,
  ]
}