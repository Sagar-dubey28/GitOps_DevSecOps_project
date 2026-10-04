output "eks_oidc_provider_arn" {
  description = "EKS IAM OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "argocd_irsa_role_arn" {
  description = "Optional Argo CD repo-server IRSA role ARN."
  value       = aws_iam_role.argocd.arn
}

output "argocd_namespace" {
  description = "Argo CD namespace."
  value       = var.argocd_namespace
}
