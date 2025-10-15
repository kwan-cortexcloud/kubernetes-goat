# --------------------------------------------------------------------------------------------------
# eks.tf - EKS Cluster and Node Group Configuration
# --------------------------------------------------------------------------------------------------

# Create the EKS Cluster
resource "aws_eks_cluster" "k8s_goat_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.k8s_goat_public_subnet[*].id
  }

  # Ensure IAM role is created before the cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
  tags = {
    yor_name  = "k8s_goat_cluster"
    yor_trace = "661f56a7-b0f2-4650-83bf-aa04c2e6bbdb"
  }
}

# Create the EKS Node Group
resource "aws_eks_node_group" "k8s_goat_node_group" {
  cluster_name    = aws_eks_cluster.k8s_goat_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.k8s_goat_public_subnet[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 1 # Allow for rolling updates
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure the cluster is created before the node group
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]

  tags = {
    Name      = "${var.cluster_name}-worker-node"
    yor_name  = "k8s_goat_node_group"
    yor_trace = "5a4d5f78-ad56-427a-9430-1be3f7ab4330"
  }
}