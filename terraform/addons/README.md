# Terraform cluster add-ons

This root is intentionally separate from `../` because Kubernetes/Helm providers need an
already-created EKS API endpoint.

Apply order:

1. `terraform -chdir=terraform init && terraform -chdir=terraform apply`
2. Update kubeconfig.
3. `terraform -chdir=terraform/addons init`
4. Apply the add-ons with variables from the base root outputs.

It installs:

- EKS IAM OIDC provider
- AWS Load Balancer Controller IRSA
- AWS Load Balancer Controller Helm release
- Argo CD Helm release
- Optional Argo CD repo-server IRSA role with ECR read permissions
- Argo CD repo-server ServiceAccount

The Argo CD IRSA role is optional and is not required for normal GitHub/Git-based
deployments into the same EKS cluster.
