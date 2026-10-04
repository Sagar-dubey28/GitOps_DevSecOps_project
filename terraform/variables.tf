variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project/resource naming prefix."
  type        = string
  default     = "python-eks-gitops"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "python-eks-gitops"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs; at least two."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs; same count as public subnets."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2 && length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Provide at least two private CIDRs and the same number as public subnets."
  }
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Trusted IPv4 CIDRs for the EKS public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Managed node group EC2 instance types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Managed node group minimum size."
  type        = number
  default     = 1
}

variable "node_group_desired_size" {
  description = "Managed node group desired size."
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Managed node group maximum size."
  type        = number
  default     = 3
}

variable "ecr_repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "python-eks-gitops"
}

variable "tags" {
  description = "Additional AWS tags."
  type        = map(string)
  default     = {}
}
