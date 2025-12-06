# TF to enable OIDC for EKS cluster to pull images from private ECR and 

# =============================================================================
# 1. CONFIGURATION & VARIABLES
# =============================================================================
data "aws_region" "current" {}

locals {
  iam_role_name_4_gh = "kwan-github-actions-ecr-eks-deploy-role"
  github_org_repo    = "kwan-cortexcloud/kubernetes-goat"
  ecr_repo_name      = "k8s-goat-build-code"
}

# =============================================================================
# 2. GITHUB OIDC SETUP
# =============================================================================

# Get GitHub's OIDC Thumbprint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the OIDC Provider in IAM
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  tags = {
    git_commit           = "dae5c9314cfd0e1913f8dde17bc22adda32afe0e"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_github_actions_eks_deploy.tf"
    git_last_modified_at = "2025-12-06 04:33:21"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "github"
    yor_trace            = "183eb20a-f746-41f5-a677-c34ba939e6cd"
  }
}

# =============================================================================
# 3. IAM ROLE (allow image push to ECR, deploy to EKS, pull from ECR)
# =============================================================================

resource "aws_iam_role" "github_actions" {
  name = local.iam_role_name_4_gh

  # Trust Policy: Allows GitHub to assume this role via OIDC
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # Limits usage to your specific repository
            "token.actions.githubusercontent.com:sub" : "repo:${local.github_org_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = {
    git_commit           = "dae5c9314cfd0e1913f8dde17bc22adda32afe0e"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_github_actions_eks_deploy.tf"
    git_last_modified_at = "2025-12-06 04:33:21"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "github_actions"
    yor_trace            = "f6fd9c0c-a472-41c0-adae-748d0d968fbc"
  }
}

resource "aws_iam_policy" "eks_describe" {
  name        = "github-actions-eks-describe-policy"
  description = "Allow GitHub Actions to discover the EKS cluster endpoint"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "*"
      }
    ]
  })
  tags = {
    git_commit           = "4dca89fd0148d3f27635e55b3a61c66342acec17"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_github_actions_eks_deploy.tf"
    git_last_modified_at = "2025-12-06 05:17:39"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "eks_describe"
    yor_trace            = "2a90bd53-5057-471b-95b9-b5893f0e375a"
  }
}

resource "aws_iam_role_policy_attachment" "eks_describe_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.eks_describe.arn
}

# =============================================================================
# 4. EKS PERMISSIONS (LEAST PRIVILEGE / NAMESPACE SCOPED)
# =============================================================================

# Map the IAM Role to the EKS Cluster
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
  tags = {
    git_commit           = "dae5c9314cfd0e1913f8dde17bc22adda32afe0e"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_github_actions_eks_deploy.tf"
    git_last_modified_at = "2025-12-06 04:33:21"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "github_actions"
    yor_trace            = "ba045345-d0b6-44c4-87c6-3652227efeb0"
  }
}

# CLUSTER VIEW: Allow deploy on across cluster 
resource "aws_eks_access_policy_association" "cluster_deploy" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions.arn

  # EditPolicy allows creating/updating Deployments, Services, etc.
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# =============================================================================
# 5. ECR PERMISSIONS (PUSH IMAGES)
# =============================================================================

resource "aws_iam_policy" "ecr_push" {
  name        = "github-actions-ecr-push-policy"
  description = "Allows GitHub Actions to push to specific ECR repo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetAuthorizationToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "AllowPushToRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${local.ecr_repo_name}"
      }
    ]
  })
  tags = {
    git_commit           = "4dca89fd0148d3f27635e55b3a61c66342acec17"
    git_file             = "platforms/aws-setup/aws-eks-tf/oidc_github_actions_eks_deploy.tf"
    git_last_modified_at = "2025-12-06 05:04:25"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
    yor_name             = "ecr_push"
    yor_trace            = "233fd70a-5dde-43e3-b461-5e751646406e"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "github_action_iam_role_arn" {
  description = "ARN of the created IAM role for GITHUB Action access."
  value       = aws_iam_role.github_actions.arn
}
