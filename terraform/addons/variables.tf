variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
}

variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  description = "Existing EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID containing the EKS cluster."
  type        = string
}

variable "load_balancer_controller_chart_version" {
  description = "AWS Load Balancer Controller chart version."
  type        = string
  default     = "1.13.0"
}

variable "argocd_chart_version" {
  description = "Argo CD chart version."
  type        = string
  default     = "10.3.2"
}

variable "argocd_namespace" {
  description = "Argo CD namespace."
  type        = string
  default     = "argocd"
}
