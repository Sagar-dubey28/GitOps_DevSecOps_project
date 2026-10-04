# Argo CD

`application.yaml` is the GitOps Application for the Python Helm chart.

`argocd-ingress.yaml` exposes the Argo CD UI through AWS ALB + ACM. Replace the
hostname and ACM certificate ARN before applying it.

The Terraform add-ons root installs Argo CD with `server.insecure=true` because
TLS termination is performed by the ALB. Do not expose the Argo CD service
directly to the internet.

Apply:

```bash
kubectl apply -f argocd/application.yaml
kubectl apply -f argocd/argocd-ingress.yaml
```
