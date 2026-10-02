# Python Application on AWS EKS using GitOps

A production-oriented assignment implementation for deploying a Python Hello World application to Amazon EKS with GitHub Actions, Amazon ECR, Argo CD, Helm, AWS ALB and ACM TLS.

## Architecture

See `docs/ARCHITECTURE.md`.

## Repository structure

```text
.
├── app/                         # Python application + Dockerfile
├── terraform/                   # VPC, EKS, ECR, IAM/IRSA and controller Helm release
│   └── addons/                  # Cluster-dependent AWS Load Balancer Controller resources
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

## Terraform infrastructure

The Terraform configuration creates the VPC, public/private subnets, IGW, a single NAT gateway, route tables, EKS cluster, private managed node group, and the `python-eks-gitops` ECR repository. It checks ECR first and reads an existing repository instead of creating a duplicate. The add-ons root configures the cluster OIDC provider, AWS Load Balancer Controller IRSA role and `kube-system/aws-load-balancer-controller` ServiceAccount, then installs the pinned Helm chart.

Install Terraform, AWS CLI, Python, and configure AWS credentials with permission to manage the resources in both roots. Review `terraform/terraform.tfvars.example`; restrict `cluster_endpoint_public_access_cidrs` to trusted client IP ranges before applying. The example uses one NAT gateway to reduce cost; private subnet egress therefore depends on that gateway and crosses AZs from other zones.

From PowerShell, copy the example variables file and edit it for your environment:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Apply the base infrastructure first:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan
$AwsRegion = terraform -chdir=terraform output -raw aws_region
$ClusterName = terraform -chdir=terraform output -raw eks_cluster_name
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
```

Then install the cluster add-ons, passing the VPC output from the base root:

```powershell
$VpcId = terraform -chdir=terraform output -raw vpc_id
$AwsRegion = terraform -chdir=terraform output -raw aws_region
$ClusterName = terraform -chdir=terraform output -raw eks_cluster_name
$ProjectName = terraform -chdir=terraform output -raw project_name
$Environment = terraform -chdir=terraform output -raw environment
terraform -chdir=terraform/addons init
terraform -chdir=terraform/addons plan `
   -var="aws_region=$AwsRegion" `
   -var="cluster_name=$ClusterName" `
   -var="project_name=$ProjectName" `
   -var="environment=$Environment" `
   -var="vpc_id=$VpcId" `
   -out=tfplan
terraform -chdir=terraform/addons apply tfplan
```

The add-ons provider reads the existing EKS cluster, so these roots must be applied in this order. Terraform state is local by default; configure a secured remote backend before team use.

## Quick start

### 1. Update Helm values

Edit:

```text
helm/python-app/values.yaml
```

Set your AWS account ID, region, hostname and ACM certificate ARN.

Set `image.repository` to the base Terraform output `ecr_repository_url`.

### 2. Update Argo CD repository URL

Edit:

```text
argocd/application.yaml
```

Replace:

```text
https://github.com/YOUR_GITHUB_USER/python-eks-gitops.git
```

with your actual repository URL.

### 3. Configure GitHub Actions secrets

For the included simple assignment workflow:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

For a stronger production implementation, replace these with GitHub OIDC + an AWS IAM role.

### 4. Install Argo CD

Install Argo CD into the `argocd` namespace if it is not already installed.

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
