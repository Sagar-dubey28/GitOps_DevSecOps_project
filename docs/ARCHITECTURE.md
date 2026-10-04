# Architecture

## AWS

```text
                    Internet
                       |
                Route 53 / DNS
                  /          \
                 /            \
        project.sagardubey.in   argocd.sagardubey.in
                 |                |
              ALB :443          ALB :443
                 |                |
               ACM              ACM
                 |                |
              EKS VPC / AWS Load Balancer Controller
                 |
        +--------+----------------------+
        |                               |
   Private subnets                Public subnets
        |                               |
   EKS managed nodes                 ALB subnets
        |
   Python Deployment
        |
   ClusterIP Service
        |
   Flask/Gunicorn :8080
```

## GitOps

```text
GitHub
  |
  +-- GitHub Actions
  |     +-- test
  |     +-- Trivy FS
  |     +-- Docker build
  |     +-- Trivy image
  |     +-- ECR
  |     +-- update Helm SHA
  |
  +-- Helm desired state
          |
        Argo CD
          |
        EKS
```

## Terraform split

`terraform/` creates AWS infrastructure.

`terraform/addons/` is deliberately separate because the Kubernetes and Helm
providers need the EKS API endpoint to exist before they can manage in-cluster
resources.

The add-ons root creates:

- OIDC provider
- AWS Load Balancer Controller IRSA + Helm release
- Argo CD + repo-server IRSA
- Metrics Server
