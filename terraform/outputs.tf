output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.cluster.name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.cluster.endpoint
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name."
  value       = var.project_name
}

output "environment" {
  description = "Environment."
  value       = var.environment
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.managed.node_group_name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}
