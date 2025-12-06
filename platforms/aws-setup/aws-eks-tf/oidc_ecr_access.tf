# TF to enable OIDC for EKS cluster to pull images from private ECR

# -----------------------------------------------------------------------------
# INPUT VARIABLES
# -----------------------------------------------------------------------------

variable "k8s_namespace" {
  description = "The Kubernetes namespace for the service account."
  type        = string
  default     = "goat"
}

variable "k8s_service_account_name" {
  description = "The name of the Kubernetes service account to create."
  type        = string
  default     = "ecr-puller-sa"
}

variable "role_name" {
  description = "The name of the IAM Role to create."
  type        = string
  default     = "kwan-ECRPullerRole"
}

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------
# Get information about the EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Get the OIDC provider's thumbprint
data "tls_certificate" "cluster_oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Get current AWS Account ID
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# IAM OIDC IDENTITY PROVIDER
# -----------------------------------------------------------------------------
#resource "aws_iam_openid_connect_provider" "oidc_provider" {
#  client_id_list  = ["sts.amazonaws.com"]
#  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
#  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
#}

# -----------------------------------------------------------------------------
# IAM POLICY AND ROLE
# -----------------------------------------------------------------------------
# IAM Policy for ECR read-only access
resource "aws_iam_policy" "ecr_readonly_policy" {
  name        = "ECRReadonlyAccessPolicy"
  description = "Grants read-only access to ECR for pulling images."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      },
    ]
  })
  tags = {
    yor_name             = "ecr_readonly_policy"
    yor_trace            = "9e411dd4-6feb-40f9-b34b-89a02fe8b5bf"
    git_commit           = "18d39a16ac04c80b36a4aa6ec548150c8755afae"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_ecr_access.tf"
    git_last_modified_at = "2025-11-20 22:09:32"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Data source to construct the trust policy for the IAM role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc_provider.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"]
    }
  }
}

# IAM Role that the Service Account will assume
resource "aws_iam_role" "ecr_puller_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    yor_name             = "ecr_puller_role"
    yor_trace            = "f4be0dcf-d162-4517-a4d7-532e5dcf217b"
    git_commit           = "18d39a16ac04c80b36a4aa6ec548150c8755afae"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_ecr_access.tf"
    git_last_modified_at = "2025-11-20 22:09:32"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Attach the ECR policy to the role
resource "aws_iam_role_policy_attachment" "ecr_policy_attach" {
  role       = aws_iam_role.ecr_puller_role.name
  policy_arn = aws_iam_policy.ecr_readonly_policy.arn
}

# -----------------------------------------------------------------------------
# STEP 4: KUBERNETES SERVICE ACCOUNT
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "kubernetes_service_account" "ecr_puller_sa" {
  metadata {
    name      = var.k8s_service_account_name
    namespace = var.k8s_namespace
    annotations = {
      # This annotation links the Service Account to the IAM Role
      "eks.amazonaws.com/role-arn" = aws_iam_role.ecr_puller_role.arn
    }
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "ecr_puller_iam_role_arn" {
  description = "ARN of the created IAM role for ECR access."
  value       = aws_iam_role.ecr_puller_role.arn
}

output "ecr_puller_kubernetes_service_account_name" {
  description = "Kubernetes Service Account for ECR image pull."
  value       = kubernetes_service_account.ecr_puller_sa.metadata[0].name
}