# --------------------------------------------------------------------------------------------------
# main.tf - Main Terraform Configuration
# --------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  cloud { 
    
    organization = "kwan-pan" 

    workspaces { 
      name = "k8s-goat" 
    } 
  } 
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  profile = var.aws_sso_profile
}

# Configure the Helm Provider
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.k8s_goat_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_goat_cluster.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.k8s_goat_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_goat_cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

# Data source to get availability zones in the specified region
data "aws_availability_zones" "available" {}
