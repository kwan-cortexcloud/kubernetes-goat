# --------------------------------------------------------------------------------------------------
# vpc.tf - VPC and Networking Configuration
# --------------------------------------------------------------------------------------------------

# Create a VPC for our EKS cluster
resource "aws_vpc" "k8s_goat_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                 = "${var.cluster_name}-vpc"
    yor_name             = "k8s_goat_vpc"
    yor_trace            = "e563c36c-28f8-469c-b2db-20bfd6acb099"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "k8s_goat_igw" {
  vpc_id = aws_vpc.k8s_goat_vpc.id

  tags = {
    Name                 = "${var.cluster_name}-igw"
    yor_name             = "k8s_goat_igw"
    yor_trace            = "d1d685c7-73d1-4b64-b58a-89abec2dc8ac"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Create public subnets for resources like load balancers
resource "aws_subnet" "k8s_goat_public_subnet" {
  count = 2

  vpc_id                  = aws_vpc.k8s_goat_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    yor_name                                    = "k8s_goat_public_subnet"
    yor_trace                                   = "d2583cf4-a53c-4e89-9b14-b41739818610"
    git_commit                                  = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file                                    = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at                        = "2025-10-15 00:32:34"
    git_last_modified_by                        = "kwan@paloaltonetworks.com"
    git_modifiers                               = "kwan"
    git_org                                     = "kwan-cortexcloud"
    git_repo                                    = "kubernetes-goat"
  }
}

# Create private subnets for the EKS worker nodes
resource "aws_subnet" "k8s_goat_private_subnet" {
  count = 2

  vpc_id            = aws_vpc.k8s_goat_vpc.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    yor_name                                    = "k8s_goat_private_subnet"
    yor_trace                                   = "8d362b15-7de4-4f05-b30e-01c828fe19e3"
    git_commit                                  = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file                                    = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at                        = "2025-10-15 00:32:34"
    git_last_modified_by                        = "kwan@paloaltonetworks.com"
    git_modifiers                               = "kwan"
    git_org                                     = "kwan-cortexcloud"
    git_repo                                    = "kubernetes-goat"
  }
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "k8s_goat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.k8s_goat_igw]

  tags = {
    Name                 = "${var.cluster_name}-nat-eip"
    yor_name             = "k8s_goat_eip"
    yor_trace            = "beda3402-564c-4e37-8b0c-66af9f29455b"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Create a NAT Gateway to allow outbound traffic from private subnets
resource "aws_nat_gateway" "k8s_goat_nat_gw" {
  allocation_id = aws_eip.k8s_goat_eip.id
  subnet_id     = aws_subnet.k8s_goat_public_subnet[0].id

  tags = {
    Name                 = "${var.cluster_name}-nat-gw"
    yor_name             = "k8s_goat_nat_gw"
    yor_trace            = "f0cd13b9-708f-441f-ba1f-e737d1b50e43"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }

  depends_on = [aws_internet_gateway.k8s_goat_igw]
}

# Create a route table for the public subnets
resource "aws_route_table" "k8s_goat_public_rt" {
  vpc_id = aws_vpc.k8s_goat_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_goat_igw.id
  }

  tags = {
    Name                 = "${var.cluster_name}-public-rt"
    yor_name             = "k8s_goat_public_rt"
    yor_trace            = "81373090-be21-49e3-85f3-4ad72eb8c529"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.k8s_goat_public_subnet[count.index].id
  route_table_id = aws_route_table.k8s_goat_public_rt.id
}

# Create a route table for the private subnets
resource "aws_route_table" "k8s_goat_private_rt" {
  vpc_id = aws_vpc.k8s_goat_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.k8s_goat_nat_gw.id
  }

  tags = {
    Name                 = "${var.cluster_name}-private-rt"
    yor_name             = "k8s_goat_private_rt"
    yor_trace            = "7df0913d-2001-4d54-9e9e-0b3908657ee6"
    git_commit           = "efd118cc07ab9024323d29f00158a21c113a6b61"
    git_file             = "platforms/aws-setup/aws-eks-tf/vpc.tf"
    git_last_modified_at = "2025-10-15 00:32:34"
    git_last_modified_by = "kwan@paloaltonetworks.com"
    git_modifiers        = "kwan"
    git_org              = "kwan-cortexcloud"
    git_repo             = "kubernetes-goat"
  }
}

# Associate the private route table with the private subnets
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.k8s_goat_private_subnet[count.index].id
  route_table_id = aws_route_table.k8s_goat_private_rt.id
}
