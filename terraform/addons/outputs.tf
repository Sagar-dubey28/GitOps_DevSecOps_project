/*
output "eks_oidc_provider_arn" {
  value = "disabled_due_to_scp"
}

output "load_balancer_controller_role_arn" {
  value = "disabled_due_to_scp"
}

output "argocd_irsa_role_arn" {
  value = "disabled_due_to_scp"
}
*/

output "argocd_namespace" {
  description = "Argo CD namespace."
  value       = var.argocd_namespace
}
