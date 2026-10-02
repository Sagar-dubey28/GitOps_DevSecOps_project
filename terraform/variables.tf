variable "aws_region" {
  description = "AWS region for the network, EKS, ECR, and load balancer controller."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project prefix used for AWS resource tags and names."
  type        = string
  default     = "python-eks-gitops"
}

variable "environment" {
  description = "Environment name included in names and tags."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name used by the existing scripts and Kubernetes tags."
  type        = string
  default     = "python-eks-gitops"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per availability zone."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Provide at least two public subnet CIDRs for EKS load balancers."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per availability zone."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Provide at least two private subnet CIDRs for the EKS cluster and nodes."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Provide the same number of public and private subnet CIDRs."
  }
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane and managed node group."
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public EKS API endpoint; restrict this to trusted addresses."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum managed node group size; zero permits the existing scale-to-zero script."
  type        = number
  default     = 0
}

variable "node_group_desired_size" {
  description = "Initial desired managed node group size."
  type        = number
  default     = 2

  validation {
    condition     = var.node_group_desired_size >= var.node_group_min_size && var.node_group_desired_size <= var.node_group_max_size
    error_message = "Desired node count must be between the configured minimum and maximum."
  }
}

variable "node_group_max_size" {
  description = "Maximum managed node group size."
  type        = number
  default     = 3
}

variable "ecr_repository_name" {
  description = "ECR repository consumed by the existing GitHub Actions workflow."
  type        = string
  default     = "python-eks-gitops"
}

variable "python_executable" {
  description = "Python executable used by the ECR existence lookup (use python3 on many Linux hosts)."
  type        = string
  default     = "python"
}