# `.dockerignore`

```text
# Root-level Docker context exclusions.
# The production image is built with app/ as the Docker build context,
# therefore app/.dockerignore is the file used by `docker build -f app/Dockerfile app`.
.git/
.github/
terraform/
helm/
argocd/
k8s/
docs/
scripts/
.env
*.tfstate
*.tfplan
__pycache__/
*.pyc

```

# `.github/workflows/ci-cd.yaml`

```text
name: CI-CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: write
  id-token: write
  security-events: write

env:
  AWS_REGION: ap-south-1
  ECR_REPOSITORY: python-eks-gitops

jobs:
  test:
    name: Test Python application
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r app/requirements.txt pytest

      - name: Compile
        run: python -m compileall app

      - name: Unit tests
        run: |
          cat > app/test_app.py <<'EOF'
          from app.app import app

          def test_health():
              client = app.test_client()
              response = client.get("/health")
              assert response.status_code == 200

          def test_ready():
              client = app.test_client()
              response = client.get("/ready")
              assert response.status_code == 200
          EOF
          PYTHONPATH=. pytest -q

  filesystem-security:
    name: Trivy filesystem scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: fs
          scan-ref: .
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: "1"

  build-scan-push:
    name: Build, scan and push image
    needs: [test, filesystem-security]
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS with OIDC
        if: ${{ vars.AWS_ROLE_TO_ASSUME != '' }}
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure AWS with access keys
        if: ${{ vars.AWS_ROLE_TO_ASSUME == '' }}
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build image
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: docker build -t "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" -f app/Dockerfile app

      - name: Scan local image with Trivy
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: ${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: "1"

      - name: Push immutable image
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: docker push "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

  update-gitops:
    name: Commit GitOps image tag
    needs: build-scan-push
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update Helm image tag
        env:
          IMAGE_TAG: ${{ github.sha }}
        run: |
          python - <<'PY'
          from pathlib import Path
          import os, re

          p = Path("helm/python-app/values.yaml")
          text = p.read_text()
          updated, count = re.subn(
              r'(?m)^  tag: ".*"$',
              f'  tag: "{os.environ["IMAGE_TAG"]}"',
              text,
              count=1,
          )
          if count != 1:
              raise SystemExit("Could not find helm image tag in values.yaml")
          p.write_text(updated)
          PY

      - name: Commit and push GitOps change
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add helm/python-app/values.yaml
          git diff --cached --quiet && exit 0
          git commit -m "chore: deploy image ${{ github.sha }}"
          git push

```

# `.gitignore`

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfplan
!*.tfvars.example
.kube/
.env
.DS_Store
__pycache__/
*.pyc

```

# `README.md`

```text
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

```

# `app/.dockerignore`

```text
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.git/
.github/
.env
test_*.py
README.md

```

# `app/app.py`

```text
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def hello():
    return jsonify({
        "message": "Hello World from Python on Amazon EKS",
        "status": "running",
    })


@app.get("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.get("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

```

# `app/requirements.txt`

```text
Flask==3.1.2
Gunicorn==23.0.0

```

# `argocd/README.md`

```text
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

```

# `argocd/application.yaml`

```text
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: python-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_GITHUB_USER/python-eks-gitops.git
    targetRevision: main
    path: helm/python-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: python-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10

```

# `argocd/argocd-ingress.yaml`

```text
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/success-codes: "200-399"
    alb.ingress.kubernetes.io/tags: "Project=python-eks-gitops,ManagedBy=terraform"
spec:
  ingressClassName: alb
  rules:
    - host: argocd.sagardubey.in
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80

```

# `docs/ARCHITECTURE.md`

```text
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

```

# `docs/ASSIGNMENT_CHECKLIST.md`

```text
# Assignment Checklist

- [x] Python Hello World application
- [x] Gunicorn/Flask container
- [x] Health endpoint
- [x] Readiness endpoint
- [x] Dockerfile and .dockerignore
- [x] Amazon ECR repository
- [x] GitHub Actions CI/CD
- [x] Unit tests
- [x] Trivy filesystem scan
- [x] Trivy image scan before push
- [x] Immutable Git SHA image tags
- [x] Argo CD Application
- [x] Helm chart
- [x] AWS Load Balancer Controller
- [x] ALB Ingress
- [x] Application ACM TLS
- [x] Argo CD UI ACM TLS
- [x] Rolling deployment
- [x] HPA
- [x] Metrics Server
- [x] PDB
- [x] GitOps rollback
- [x] Emergency Kubernetes rollback
- [x] Shutdown procedure
- [x] Startup procedure
- [x] Node group scale-to-zero scripts
- [x] VPC, public/private subnets, IGW, NAT, route tables
- [x] EKS cluster and managed node group
- [x] EKS OIDC/IRSA
- [x] AWS Load Balancer Controller IAM policy/role
- [x] Optional Argo CD repo-server IRSA role
- [ ] Replace GitHub repository URL
- [ ] Replace AWS account ID
- [ ] Replace ACM certificate ARNs
- [ ] Configure DNS
- [ ] Configure GitHub OIDC or access-key secrets
- [ ] Restrict EKS API endpoint CIDRs
- [ ] Run Terraform and validate the deployed environment

```

# `docs/OPERATIONS.md`

```text
# Operations Runbook

## Daily verification

```bash
aws sts get-caller-identity
kubectl get nodes
kubectl -n argocd get pods
kubectl -n python-app get pods,svc,ingress
kubectl -n python-app rollout status deployment/python-app
```

## Provision

Run the base Terraform root first, then the add-ons root. See the main README.

## Application deployment

Push to `main`. GitHub Actions tests and scans the code, builds/scans the image,
pushes the immutable SHA tag to ECR and updates Helm values. Argo CD syncs the
resulting Git change.

## ALB troubleshooting

```bash
kubectl -n python-app describe ingress python-app
kubectl -n kube-system logs deployment/aws-load-balancer-controller
```

Check:

- public subnet tags: `kubernetes.io/role/elb=1`
- AWS Load Balancer Controller is Ready
- ACM certificate ARN is correct and same-region
- DNS points to the ALB
- service target port is 8080

## HPA troubleshooting

```bash
kubectl top nodes
kubectl top pods -n python-app
kubectl -n python-app get hpa
```

Metrics Server is installed by the Terraform add-ons root.

## Shutdown

```bash
./scripts/shutdown.sh
```

For node-group shutdown:

```bash
./scripts/scale-nodegroup-to-zero.sh CLUSTER NODEGROUP REGION
```

The shutdown script disables Argo CD automated sync before deleting the
application Ingress, preventing immediate recreation.

## Startup

```bash
./scripts/startup.sh CLUSTER NODEGROUP REGION 2
```

This scales nodes up, waits for a Ready node, restores automated sync and
refreshes the Argo CD Application.

## Terraform changes

Always review:

```bash
terraform -chdir=terraform plan
terraform -chdir=terraform/addons plan ...
```

Do not use `terraform destroy` casually; EKS, ECR and IAM resources can affect
the whole environment.

```

# `docs/ROLLBACK.md`

```text
# Rollback Strategy

## Preferred: Git revert

Git is the source of truth.

```bash
git log --oneline -- helm/python-app/values.yaml
git revert <bad-commit>
git push origin main
```

Argo CD detects the desired-state change and deploys the previous SHA-tagged image.

## Emergency Kubernetes rollback

```bash
./scripts/rollback.sh
```

This invokes:

```bash
kubectl rollout undo deployment/python-app
```

It is temporary if Argo CD automated sync is enabled. Follow it with a Git
revert to make the rollback permanent.

## Argo CD history

```bash
kubectl -n argocd get application python-app -o yaml
```

If using the Argo CD CLI:

```bash
argocd app history python-app
```

Prefer correcting Git rather than leaving the cluster in a state that differs
from the repository.

```

# `docs/SECURITY.md`

```text
# Security Controls

## CI/CD

- Unit tests and Python compilation run on every pull request.
- Trivy scans the repository filesystem.
- Trivy scans the locally built container before it is pushed.
- HIGH/CRITICAL vulnerabilities with fixes block the pipeline.
- ECR uses immutable image tags.
- ECR scan-on-push is enabled.

## Container

- Python slim base image.
- Non-root user.
- Linux capabilities dropped.
- Privilege escalation disabled.
- Read-only root filesystem.
- Writable `/tmp` mounted as an `emptyDir`.
- Health/readiness endpoints are separate.

## AWS

- EKS nodes use private subnets.
- Public subnets are reserved for internet-facing ALBs.
- AWS Load Balancer Controller uses IRSA.
- Argo CD repo-server has an optional, limited ECR-read IRSA role.
- GitHub OIDC is preferred over long-lived access keys.
- EKS API public CIDRs should be restricted to trusted administrator IPs.

## Secrets

Never commit:

- AWS access keys
- private keys
- Kubernetes secret values
- ACM private material
- Terraform state containing secrets

Use AWS Secrets Manager/SSM or another approved secret-management system for
application secrets.

```

# `docs/SSL.md`

```text
# SSL/TLS

## Application

The Python application uses an AWS ALB with an ACM certificate.

1. Request/validate an ACM certificate for `project.sagardubey.in`.
2. Put its ARN in `helm/python-app/values.yaml`.
3. Argo CD deploys the Ingress.
4. AWS Load Balancer Controller creates the ALB.
5. Create the DNS record for the ALB.
6. HTTP is redirected to HTTPS.

The ACM certificate must be in the same AWS region as the ALB.

## Argo CD UI

The repository includes `argocd/argocd-ingress.yaml`.

Configure:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
```

and:

```yaml
host: argocd.sagardubey.in
```

The Terraform Argo CD Helm release sets:

```yaml
configs:
  params:
    server.insecure: "true"
```

This means Argo CD server traffic inside the cluster is HTTP and TLS terminates
at the ALB. The Argo CD service remains `ClusterIP`.

Do not expose the Argo CD service directly as a public LoadBalancer.

```

# `helm/python-app/Chart.yaml`

```text
apiVersion: v2
name: python-app
description: Python Hello World application deployed to Amazon EKS through Argo CD
type: application
version: 0.1.0
appVersion: "1.0.0"

```

# `helm/python-app/templates/deployment.yaml`

```text
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "python-app.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "python-app.name" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "python-app.name" . }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "python-app.name" . }}
    spec:
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: python-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
            timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
            failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
            timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
            failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}

```

# `helm/python-app/templates/hpa.yaml`

```text
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "python-app.fullname" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "python-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}

```

# `helm/python-app/templates/ingress.yaml`

```text
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "python-app.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "python-app.name" . }}
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.certificateArn | quote }}
    alb.ingress.kubernetes.io/healthcheck-path: {{ .Values.ingress.healthcheckPath | quote }}
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/tags: "Project=python-eks-gitops,ManagedBy=argocd"
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - host: {{ .Values.ingress.host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "python-app.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}

```

# `helm/python-app/templates/pdb.yaml`

```text
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "python-app.fullname" . }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "python-app.name" . }}
{{- end }}

```

# `helm/python-app/templates/service.yaml`

```text
apiVersion: v1
kind: Service
metadata:
  name: {{ include "python-app.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "python-app.name" . }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: {{ include "python-app.name" . }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.containerPort }}
      protocol: TCP
      name: http

```

# `helm/python-app/values.yaml`

```text
replicaCount: 2

image:
  # Replace ACCOUNT_ID with your AWS account ID.
  repository: ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/python-eks-gitops
  tag: "initial"
  pullPolicy: IfNotPresent

containerPort: 8080

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

probes:
  liveness:
    path: /health
    initialDelaySeconds: 10
    periodSeconds: 15
    timeoutSeconds: 3
    failureThreshold: 3
  readiness:
    path: /ready
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 3

ingress:
  enabled: true
  className: alb
  host: project.sagardubey.in
  certificateArn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
  healthcheckPath: /health

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1

```

# `k8s/namespace.yaml`

```text
apiVersion: v1
kind: Namespace
metadata:
  name: python-app

```

# `scripts/rollback.sh`

```text
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-python-app}"
DEPLOYMENT="${2:-python-app}"

echo "Current deployment history:"
kubectl -n "$NAMESPACE" rollout history "deployment/$DEPLOYMENT"

echo
echo "Performing an emergency Kubernetes rollback..."
kubectl -n "$NAMESPACE" rollout undo "deployment/$DEPLOYMENT"
kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT" --timeout=5m

echo
echo "IMPORTANT: Git is the source of truth."
echo "If Argo CD automated sync is enabled, it may restore the Git-defined image."
echo "For a permanent rollback, revert the bad image-tag commit in Git and push it."

```

# `scripts/scale-nodegroup-to-zero.sh`

```text
#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:?Usage: $0 <cluster-name> <nodegroup-name> [region]}"
NODEGROUP="${2:?Usage: $0 <cluster-name> <nodegroup-name> [region]}"
REGION="${3:-ap-south-1}"

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region "$REGION"

echo "Managed node group scaled to zero."
echo "EKS control-plane charges remain."

```

# `scripts/scale-nodegroup-up.sh`

```text
#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:?Usage: $0 <cluster-name> <nodegroup-name> [region] [desired]}"
NODEGROUP="${2:?Usage: $0 <cluster-name> <nodegroup-name> [region] [desired]}"
REGION="${3:-ap-south-1}"
DESIRED="${4:-2}"

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --scaling-config minSize=1,maxSize=3,desiredSize="$DESIRED" \
  --region "$REGION"

echo "Managed node group startup requested."

```

# `scripts/shutdown.sh`

```text
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${APP_NAMESPACE:-python-app}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
CLUSTER="${1:-}"
NODEGROUP="${2:-}"
REGION="${3:-ap-south-1}"

echo "Disabling Argo CD automated sync so shutdown is not immediately undone..."
kubectl -n "$ARGOCD_NAMESPACE" patch application python-app \
  --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]' 2>/dev/null || true

echo "Scaling application to zero..."
kubectl -n "$NAMESPACE" scale deployment/python-app --replicas=0 2>/dev/null || true

echo "Deleting application ALB Ingress..."
kubectl -n "$NAMESPACE" delete ingress python-app --ignore-not-found

if [[ -n "$CLUSTER" && -n "$NODEGROUP" ]]; then
  echo "Scaling managed node group to zero..."
  aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --scaling-config minSize=0,maxSize=0,desiredSize=0 \
    --region "$REGION"
fi

echo
echo "Shutdown complete."
echo "EKS control-plane charges continue while the cluster exists."

```

# `scripts/startup.sh`

```text
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${APP_NAMESPACE:-python-app}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
CLUSTER="${1:-}"
NODEGROUP="${2:-}"
REGION="${3:-ap-south-1}"
DESIRED="${4:-2}"

if [[ -n "$CLUSTER" && -n "$NODEGROUP" ]]; then
  echo "Scaling managed node group up..."
  aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --scaling-config minSize=1,maxSize=3,desiredSize="$DESIRED" \
    --region "$REGION"
fi

echo "Waiting for at least one Kubernetes node..."
for _ in {1..60}; do
  if kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready "; then
    break
  fi
  sleep 10
done

echo "Re-enabling Argo CD automated sync..."
kubectl -n "$ARGOCD_NAMESPACE" patch application python-app \
  --type=json \
  -p='[{"op":"add","path":"/spec/syncPolicy/automated","value":{"prune":true,"selfHeal":true,"allowEmpty":false}}]'

echo "Applying Argo CD UI Ingress if configured..."
if [[ -f argocd/argocd-ingress.yaml ]]; then
  kubectl apply -f argocd/argocd-ingress.yaml
fi

echo "Requesting an immediate Argo CD sync..."
kubectl -n "$ARGOCD_NAMESPACE" annotate application python-app \
  argocd.argoproj.io/refresh=hard --overwrite

echo "Startup requested. Watch with:"
echo "kubectl -n $NAMESPACE get pods,ingress"

```

# `terraform/addons/README.md`

```text
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

```

# `terraform/addons/helm.tf`

```text
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = "true"
      }
    }
    server = {
      service = {
        type = "ClusterIP"
      }
    }
    repoServer = {
      serviceAccount = {
        create = false
        name   = "argocd-repo-server"
      }
    }
  })]

  depends_on = [kubernetes_service_account_v1.argocd_repo_server]
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.load_balancer_controller_chart_version
  namespace  = "kube-system"

  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [kubernetes_service_account_v1.load_balancer_controller]
}


resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.13.1"
  namespace        = "kube-system"
  create_namespace = false

  wait            = true
  timeout         = 600
  atomic          = true

  depends_on = [helm_release.load_balancer_controller]
}

```

# `terraform/addons/iam.tf`

```text
data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[length(data.tls_certificate.eks_oidc.certificates) - 1].sha1_fingerprint
  ]

  tags = {
    Name        = "${var.cluster_name}-${var.environment}-oidc"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-${var.environment}-aws-load-balancer-controller"
  description = "Permissions for AWS Load Balancer Controller."
  policy      = file("${path.module}/../iam/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.cluster_name}-${var.environment}-aws-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.load_balancer_controller]
}

# Argo CD itself does not need AWS permissions to deploy into the same EKS
# cluster. This IRSA role is provided for optional AWS API/ECR integrations.
resource "aws_iam_policy" "argocd_ecr_read" {
  name        = "${var.cluster_name}-${var.environment}-argocd-ecr-read"
  description = "Optional ECR read permissions for Argo CD integrations."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "argocd" {
  name = "${var.cluster_name}-${var.environment}-argocd-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:argocd-repo-server"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_ecr_read" {
  role       = aws_iam_role.argocd.name
  policy_arn = aws_iam_policy.argocd_ecr_read.arn
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_service_account_v1" "argocd_repo_server" {
  metadata {
    name      = "argocd-repo-server"
    namespace = var.argocd_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd.arn
    }
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

```

# `terraform/addons/outputs.tf`

```text
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

```

# `terraform/addons/providers.tf`

```text
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

```

# `terraform/addons/variables.tf`

```text
variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
}

variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  description = "Existing EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID containing the EKS cluster."
  type        = string
}

variable "load_balancer_controller_chart_version" {
  description = "AWS Load Balancer Controller chart version."
  type        = string
  default     = "1.13.0"
}

variable "argocd_chart_version" {
  description = "Argo CD chart version."
  type        = string
  default     = "10.3.2"
}

variable "argocd_namespace" {
  description = "Argo CD namespace."
  type        = string
  default     = "argocd"
}

```

# `terraform/addons/versions.tf`

```text
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

```

# `terraform/ecr.tf`

```text
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = var.ecr_repository_name
  })

  lifecycle {
    prevent_destroy = true
  }
}

```

# `terraform/eks.tf`

```text
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-${var.environment}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.cluster_name}-${var.environment}-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-${var.environment}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.cluster_name}-${var.environment}-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.eks_nodes.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_cluster_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "managed" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-${var.environment}-managed"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_x86_64_STANDARD"
  disk_size       = 20

  scaling_config {
    min_size     = var.node_group_min_size
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = var.environment
    workload    = "python-app"
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${var.environment}-managed"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_nodes]
}
```

# `terraform/iam/aws-load-balancer-controller-policy.json`

```text
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iam:CreateServiceLinkedRole"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "ec2:GetSecurityGroupsForVpc",
        "ec2:DescribeIpamPools",
        "ec2:DescribeRouteTables",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTrustStores",
        "elasticloadbalancing:DescribeListenerAttributes",
        "elasticloadbalancing:DescribeCapacityReservation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateSecurityGroup"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateTags"],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "StringEquals": {"ec2:CreateAction": "CreateSecurityGroup"},
        "Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "false"}
      }
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateTags", "ec2:DeleteTags"],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup"
      ],
      "Resource": "*",
      "Condition": {"Null": {"aws:ResourceTag/elbv2.k8s.aws/cluster": "false"}}
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"],
      "Resource": "*",
      "Condition": {"Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "false"}}
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:ModifyListenerAttributes",
        "elasticloadbalancing:ModifyCapacityReservation",
        "elasticloadbalancing:ModifyIpPools"
      ],
      "Resource": "*",
      "Condition": {"Null": {"aws:ResourceTag/elbv2.k8s.aws/cluster": "false"}}
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:AddTags"],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "StringEquals": {
          "elasticloadbalancing:CreateAction": ["CreateTargetGroup", "CreateLoadBalancer"]
        },
        "Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "false"}
      }
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"],
      "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule",
        "elasticloadbalancing:SetRulePriorities"
      ],
      "Resource": "*"
    }
  ]
}
```

# `terraform/network.tf`

```text
locals {
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    length(var.public_subnet_cidrs),
  )
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${var.project_name}-${var.environment}-public-${local.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                                        = "${var.project_name}-${var.environment}-private-${local.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

# `terraform/outputs.tf`

```text
output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.cluster.name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.cluster.endpoint
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name."
  value       = var.project_name
}

output "environment" {
  description = "Environment."
  value       = var.environment
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.managed.node_group_name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}

```

# `terraform/providers.tf`

```text
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge({
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }, var.tags)
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

```

# `terraform/variables.tf`

```text
variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project/resource naming prefix."
  type        = string
  default     = "python-eks-gitops"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "python-eks-gitops"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs; at least two."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs; same count as public subnets."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2 && length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Provide at least two private CIDRs and the same number as public subnets."
  }
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Trusted IPv4 CIDRs for the EKS public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Managed node group EC2 instance types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Managed node group minimum size."
  type        = number
  default     = 1
}

variable "node_group_desired_size" {
  description = "Managed node group desired size."
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Managed node group maximum size."
  type        = number
  default     = 3
}

variable "ecr_repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "python-eks-gitops"
}

variable "tags" {
  description = "Additional AWS tags."
  type        = map(string)
  default     = {}
}

```

# `terraform/versions.tf`

```text
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 7.0"
    }
  }
}

```
