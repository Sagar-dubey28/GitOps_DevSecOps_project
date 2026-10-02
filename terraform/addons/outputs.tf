output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN used for EKS IRSA."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL exposed by the EKS cluster."
  value       = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "load_balancer_controller_role_arn" {
  description = "IRSA role ARN annotated on the controller ServiceAccount."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "load_balancer_controller_service_account" {
  description = "Namespace and name of the Terraform-managed controller ServiceAccount."
  value       = "${kubernetes_service_account_v1.load_balancer_controller.metadata[0].namespace}/${kubernetes_service_account_v1.load_balancer_controller.metadata[0].name}"
}