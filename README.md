# Python EKS GitOps + DevSecOps

Production-oriented assignment project for a Python Hello World application on
Amazon EKS using Terraform, Amazon ECR, GitHub Actions, Trivy, Helm, Argo CD,
AWS Load Balancer Controller, ALB and ACM.

## Architecture

```text
Developer
   |
   v
GitHub main
   |
   +--> GitHub Actions
   |      |
   |      +--> pytest / compile
   |      +--> Trivy filesystem scan
   |      +--> Docker build
   |      +--> Trivy image scan
   |      +--> ECR push (immutable SHA tag)
   |      +--> update Helm values.yaml
   |
   v
Git repository (desired state)
   |
   v
Argo CD
   |
   v
Amazon EKS
   |
   +--> Helm Deployment --> Flask/Gunicorn
   |
   +--> Service
   |
   +--> ALB Ingress --> AWS Load Balancer Controller
   |                      |
   |                      +--> ACM certificate
   |
   +--> HPA --> Metrics Server
```

Application URL: `https://project.sagardubey.in`

Argo CD UI URL: `https://argocd.sagardubey.in`

Replace both hostnames/certificate ARNs if you use different DNS names.

## Repository structure

```text
.
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── argocd/
│   ├── README.md
│   ├── application.yaml
│   └── argocd-ingress.yaml
├── docs/
│   ├── ARCHITECTURE.md
│   ├── ASSIGNMENT_CHECKLIST.md
│   ├── OPERATIONS.md
│   ├── ROLLBACK.md
│   ├── SECURITY.md
│   └── SSL.md
├── helm/python-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── k8s/
│   └── namespace.yaml
├── scripts/
│   ├── rollback.sh
│   ├── scale-nodegroup-to-zero.sh
│   ├── scale-nodegroup-up.sh
│   ├── shutdown.sh
│   └── startup.sh
├── terraform/
│   ├── addons/
│   │   ├── helm.tf
│   │   ├── iam.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── iam/
│   │   └── aws-load-balancer-controller-policy.json
│   ├── ecr.tf
│   ├── eks.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
└── .github/workflows/ci-cd.yaml
```

## Prerequisites

- AWS account with permissions to create VPC/EKS/IAM/ECR resources
- AWS CLI configured
- Terraform >= 1.5
- kubectl
- Helm 3
- Docker
- Git
- Python 3.12
- An ACM certificate in the same AWS region as the ALB
- DNS control for the application and Argo CD hostnames

Verify:

```bash
aws sts get-caller-identity
terraform version
kubectl version --client
helm version
docker version
```

## 1. Configure Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`.

**Important:** replace `YOUR_PUBLIC_IP/32` with the public IP/CIDR from which
you will administer the EKS API. Do not leave `0.0.0.0/0` for a real deployment.

The default design uses one NAT Gateway to reduce cost. A production multi-AZ
design can use one NAT Gateway per AZ.

## 2. Create VPC, EKS, nodes and ECR

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan
```

Get outputs:

```bash
terraform -chdir=terraform output
```

Configure kubectl:

```bash
aws eks update-kubeconfig \
  --name "$(terraform -chdir=terraform output -raw eks_cluster_name)" \
  --region "$(terraform -chdir=terraform output -raw aws_region)"
```

## 3. Install cluster add-ons

The add-ons root is intentionally separate because its Kubernetes and Helm
providers require an already-existing EKS API.

```bash
REGION="$(terraform -chdir=terraform output -raw aws_region)"
CLUSTER="$(terraform -chdir=terraform output -raw eks_cluster_name)"
VPC_ID="$(terraform -chdir=terraform output -raw vpc_id)"
PROJECT="$(terraform -chdir=terraform output -raw project_name)"
ENVIRONMENT="$(terraform -chdir=terraform output -raw environment)"

terraform -chdir=terraform/addons init
terraform -chdir=terraform/addons plan \
  -var="aws_region=$REGION" \
  -var="cluster_name=$CLUSTER" \
  -var="project_name=$PROJECT" \
  -var="environment=$ENVIRONMENT" \
  -var="vpc_id=$VPC_ID" \
  -out=tfplan

terraform -chdir=terraform/addons apply tfplan
```

This installs:

- EKS OIDC provider
- AWS Load Balancer Controller IRSA
- AWS Load Balancer Controller
- Argo CD
- Optional Argo CD repo-server IRSA role for ECR integrations
- Metrics Server for HPA

The Argo CD IRSA role is intentionally least-purpose: normal GitHub/Git based
Argo CD deployments into this cluster do not require AWS API access.

## 4. Configure the Git repository

Edit `argocd/application.yaml`:

```yaml
repoURL: https://github.com/YOUR_GITHUB_USER/python-eks-gitops.git
```

Replace it with your actual repository URL.

Edit `helm/python-app/values.yaml`:

```yaml
image:
  repository: ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/python-eks-gitops

ingress:
  host: project.sagardubey.in
  certificateArn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
```

Edit `argocd/argocd-ingress.yaml`:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
...
host: argocd.sagardubey.in
```

## 5. Configure GitHub Actions AWS authentication

Preferred: GitHub OIDC.

Create an AWS IAM role trusted by:

```text
token.actions.githubusercontent.com
```

with a trust condition restricted to your GitHub repository and branch. Give it
only the ECR permissions required by this workflow.

Then create a GitHub repository variable:

```text
AWS_ROLE_TO_ASSUME
```

Alternative for an assignment: create repository secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

The workflow uses OIDC when `AWS_ROLE_TO_ASSUME` is set; otherwise it falls
back to access-key secrets.

## 6. Create the Argo CD Application

After pushing the repository:

```bash
kubectl apply -f argocd/application.yaml
kubectl apply -f argocd/argocd-ingress.yaml
```

Check:

```bash
kubectl -n argocd get pods
kubectl -n argocd get application python-app
kubectl -n python-app get pods
kubectl -n python-app get ingress
```

The first GitHub Actions run creates an immutable ECR image tagged with the
Git SHA and updates `helm/python-app/values.yaml`. Argo CD then syncs that Git
change.

## 7. DNS

After the ALBs are provisioned:

```bash
kubectl -n python-app get ingress python-app
kubectl -n argocd get ingress argocd-server
```

Create DNS records for:

```text
project.sagardubey.in
argocd.sagardubey.in
```

pointing to their respective ALB DNS names. With Route 53, use an Alias record;
with another DNS provider, use the provider's supported ALB/CNAME configuration.

## 8. TLS

ACM terminates TLS at the ALB.

Application:

```text
https://project.sagardubey.in
        |
       ALB :443
        |
      HTTP
        |
 Kubernetes Service
        |
 Flask/Gunicorn :8080
```

Argo CD:

```text
https://argocd.sagardubey.in
        |
       ALB :443
        |
      HTTP
        |
 argocd-server :80
```

Argo CD is configured with `server.insecure=true` because TLS termination is
handled by the ALB. Do not expose the ClusterIP service directly.

## 9. CI/CD

A push to `main` performs:

1. Python compile and unit tests
2. Trivy filesystem scan
3. Docker build
4. Trivy image scan of the local image
5. ECR push with the immutable Git SHA
6. Helm `values.yaml` image-tag update
7. Git commit/push
8. Argo CD detects the Git change
9. Helm Deployment performs a rolling update

A pull request runs the test and filesystem-security jobs but does not push an
image or change the GitOps tag.

## 10. Rollback

### Preferred GitOps rollback

```bash
git log --oneline -- helm/python-app/values.yaml
git revert <bad-commit>
git push origin main
```

Argo CD will deploy the image tag defined by the reverted Git state.

### Emergency Kubernetes rollback

```bash
./scripts/rollback.sh
```

This is temporary if Argo CD automated sync remains enabled. Correct the Git
desired state afterward.

## 11. Shutdown / cost saving

Application and ALB shutdown:

```bash
./scripts/shutdown.sh
```

The script disables Argo CD automated sync, scales the application to zero and
deletes the application Ingress.

To also scale the managed node group to zero:

```bash
./scripts/shutdown.sh python-eks-gitops python-eks-gitops-managed ap-south-1
```

Or separately:

```bash
./scripts/scale-nodegroup-to-zero.sh python-eks-gitops python-eks-gitops-managed ap-south-1
```

The EKS control plane and other resources can still incur charges.

## 12. Startup

If the node group was scaled to zero:

```bash
./scripts/startup.sh python-eks-gitops python-eks-gitops-managed ap-south-1 2
```

Otherwise:

```bash
./scripts/startup.sh
```

The script restores Argo CD automated sync and applies the Argo CD UI Ingress.

## 13. Health checks

Local:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

Kubernetes:

```bash
kubectl -n python-app get pods
kubectl -n python-app get svc
kubectl -n python-app get ingress
kubectl -n python-app rollout status deployment/python-app
```

## Important production notes

- Pin provider/chart/action versions and review them before upgrades.
- Use GitHub OIDC instead of long-lived AWS access keys.
- Restrict the EKS public API CIDR.
- Use a remote, encrypted Terraform backend for team use.
- Use one NAT Gateway per AZ if high availability of private-subnet egress is required.
- Keep ECR immutable tags; the Git SHA is the deployment identifier.
- Do not store AWS credentials, certificate private keys or secrets in Git.
