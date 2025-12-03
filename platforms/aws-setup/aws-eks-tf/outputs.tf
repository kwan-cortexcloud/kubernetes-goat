# --------------------------------------------------------------------------------------------------
# outputs.tf - Output Values
# --------------------------------------------------------------------------------------------------

output "cluster_endpoint" {
  description = "Endpoint for your EKS cluster."
  value       = aws_eks_cluster.k8s_goat_cluster.endpoint
}

output "cluster_name" {
  description = "The name of your EKS cluster."
  value       = aws_eks_cluster.k8s_goat_cluster.name
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig for your cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}