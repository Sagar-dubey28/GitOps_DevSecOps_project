output "vpc_id" {
  description = "ID of the project VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public load balancer subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private EKS subnets."
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.cluster.name
}

output "aws_region" {
  description = "AWS region for the deployed platform."
  value       = var.aws_region
}

output "project_name" {
  description = "Project naming prefix used by the platform."
  value       = var.project_name
}

output "environment" {
  description = "Environment name used by the platform."
  value       = var.environment
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.cluster.endpoint
}

output "ecr_repository_url" {
  description = "ECR URL used by the existing GitHub Actions workflow and Helm chart."
  value       = data.external.ecr_repository_lookup.result.exists == "true" ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.app[0].repository_url
}