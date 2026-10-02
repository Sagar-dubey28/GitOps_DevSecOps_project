variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project prefix used for AWS resource tags and names."
  type        = string
  default     = "python-eks-gitops"
}

variable "environment" {
  description = "Environment name used in IAM resource names."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Existing EKS cluster name."
  type        = string
  default     = "python-eks-gitops"
}

variable "vpc_id" {
  description = "VPC ID from the base Terraform root."
  type        = string
}

variable "load_balancer_controller_chart_version" {
  description = "Pinned AWS Load Balancer Controller Helm chart version."
  type        = string
  default     = "1.13.0"
}