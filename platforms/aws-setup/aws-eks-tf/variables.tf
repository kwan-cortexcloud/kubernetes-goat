# --------------------------------------------------------------------------------------------------
# variables.tf - Input Variables
# --------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "k8s-goat-cluster"
}

variable "node_instance_type" {
  description = "The instance type for the EKS worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_count" {
  description = "The desired number of worker nodes."
  type        = number
  default     = 2
}

variable "aws_sso_profile" {
  description = "local AWS profile for credential."
  type        = string
  default     = ""
}