# Python Application on AWS EKS using GitOps

A production-oriented assignment implementation for deploying a Python Hello World application to Amazon EKS with GitHub Actions, Amazon ECR, Argo CD, Helm, AWS ALB and ACM TLS.

## Architecture

See `docs/ARCHITECTURE.md`.

## Repository structure

```text
.
├── app/                         # Python application + Dockerfile
├── helm/python-app/             # Helm chart and ALB Ingress
├── argocd/                      # Argo CD Application
├── k8s/                         # Kubernetes bootstrap manifests
├── scripts/                     # rollback/shutdown/startup helpers
├── docs/                        # architecture, security, SSL, operations
└── .github/workflows/           # GitHub Actions CI/CD
```

## Deployment flow

```text
Git push
   ↓
GitHub Actions
   ↓
Tests + Trivy
   ↓
Docker build
   ↓
Trivy image scan
   ↓
Amazon ECR
   ↓
Update Helm image tag in Git
   ↓
Argo CD detects Git change
   ↓
Amazon EKS
   ↓
AWS ALB + ACM HTTPS
   ↓
Python application
```

## What you must replace

Search for:

```text
YOUR_GITHUB_USER
ACCOUNT_ID
AWS_REGION
python.example.com
REPLACE_ME
```

The example defaults to `ap-south-1`.

## Important prerequisites

The repository assumes the EKS platform has already been created and that:

- AWS Load Balancer Controller is installed.
- Its IAM permissions/service account are configured.
- ECR repository `python-eks-gitops` exists.
- ACM certificate exists in the ALB region.
- GitHub Actions can authenticate to AWS.
- Argo CD is installed in the cluster.

## Quick start

### 1. Create ECR repository

```bash
aws ecr create-repository \
  --repository-name python-eks-gitops \
  --region ap-south-1
```

If it already exists, ignore the error.

### 2. Update Helm values

Edit:

```text
helm/python-app/values.yaml
```

Set your AWS account ID, region, hostname and ACM certificate ARN.

### 3. Update Argo CD repository URL

Edit:

```text
argocd/application.yaml
```

Replace:

```text
https://github.com/YOUR_GITHUB_USER/python-eks-gitops.git
```

with your actual repository URL.

### 4. Configure GitHub Actions secrets

For the included simple assignment workflow:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

For a stronger production implementation, replace these with GitHub OIDC + an AWS IAM role.

### 5. Install the Argo CD application

```bash
kubectl apply -f argocd/application.yaml
```

### 6. Push a change

```bash
git add .
git commit -m "initial gitops deployment"
git push origin main
```

GitHub Actions builds/scans/pushes the image and updates the Helm tag. Argo CD then deploys it.

## Rollback

Preferred:

```bash
git log --oneline -- helm/python-app/values.yaml
git revert <bad-commit>
git push origin main
```

Emergency:

```bash
./scripts/rollback.sh
```

See `docs/ROLLBACK.md`.

## Shutdown / cost optimization

Application shutdown:

```bash
./scripts/shutdown.sh
```

Optional managed node group scale-down:

```bash
./scripts/scale-nodegroup-to-zero.sh CLUSTER NODEGROUP ap-south-1
```

Startup:

```bash
./scripts/scale-nodegroup-up.sh CLUSTER NODEGROUP ap-south-1 2
```

The EKS control plane is not free while the cluster exists; check current AWS pricing before using this approach.

## Deliverables covered

- Python sample application
- GitHub source repository structure
- GitHub Actions CI/CD
- Trivy security scanning
- Amazon ECR publishing
- Argo CD configuration
- Helm Kubernetes manifests
- ALB configuration
- ACM HTTPS configuration
- Architecture diagram
- Security documentation
- Rollback procedure
- Shutdown/startup procedure
- Cost optimization approach

## Assignment note

This repository intentionally does not contain real AWS credentials, private keys, certificate IDs, account IDs or DNS records. Those must be supplied in your own environment.
