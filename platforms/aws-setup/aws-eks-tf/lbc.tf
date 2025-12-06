# --------------------------------------------------------------------------------------------------
# lbc.tf - AWS Load Balancer Controller Configuration
# --------------------------------------------------------------------------------------------------

# Create an IAM OIDC Identity Provider for the cluster
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.k8s_goat_cluster.identity[0].oidc[0].issuer
  tags = {
    git_commit           = "18d39a16ac04c80b36a4aa6ec548150c8755afae"
    git_file             = "platforms/aws-setup/aws-eks-tf/lbc.tf"
    git_last_modified_at = "2025-11-20 22:09:32"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "eks_oidc_provider"
    yor_trace            = "5831fc05-5a08-4c4f-a07f-c5b89f7545bc"
  }
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.k8s_goat_cluster.identity[0].oidc[0].issuer
}

# IAM Policy for the AWS Load Balancer Controller
resource "aws_iam_policy" "lbc_policy" {
  name        = "${var.cluster_name}-lbc-policy"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
  tags = {
    git_commit           = "18d39a16ac04c80b36a4aa6ec548150c8755afae"
    git_file             = "platforms/aws-setup/aws-eks-tf/lbc.tf"
    git_last_modified_at = "2025-11-20 22:09:32"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "lbc_policy"
    yor_trace            = "4c56f285-812b-4d62-8988-7bec66d52035"
  }
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
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
  tags = {
    git_commit           = "18d39a16ac04c80b36a4aa6ec548150c8755afae"
    git_file             = "platforms/aws-setup/aws-eks-tf/lbc.tf"
    git_last_modified_at = "2025-11-20 22:09:32"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "lbc_role"
    yor_trace            = "0b8f8824-f232-4e04-ae82-7f25057f9631"
  }
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

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.lbc_role.arn
    }
  ]

  depends_on = [
    aws_eks_node_group.k8s_goat_node_group,
    aws_iam_role_policy_attachment.lbc_policy_attachment,
  ]
}