# Operations Runbook

## Prerequisites

Install/configure:

- AWS CLI
- kubectl
- Helm 3
- Docker
- Git
- Argo CD CLI (optional)

Verify:

```bash
aws sts get-caller-identity
kubectl get nodes
helm version
```

## Provision AWS infrastructure

The Terraform base root creates VPC/EKS/ECR, and `terraform/addons` installs controller IRSA and Helm resources after EKS exists. Follow the PowerShell commands in the repository README, and restrict the public EKS endpoint CIDRs in `terraform/terraform.tfvars` before applying.

The ECR lookup requires AWS CLI credentials with `ecr:DescribeRepositories`; Terraform also needs permission to create the infrastructure and IAM resources. If a controller release or its ServiceAccount already exists in the AWS cluster outside this repository, inspect and import it into the add-ons Terraform state before applying.

After Terraform, provide an ACM certificate ARN in the same region as the ALB and configure DNS to the ALB hostname after it is created.

## GitHub setup

Add the following repository secrets if using the included access-key workflow:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Set the ECR URL from `terraform -chdir=terraform output -raw ecr_repository_url`, plus these values, in `helm/python-app/values.yaml`:

```yaml
image:
  repository: ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/python-eks-gitops

ingress:
  host: python.example.com
  certificateArn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/REPLACE_ME
```

Update the repository URL in `argocd/application.yaml`.

## Deploy Argo CD application

```bash
kubectl apply -f argocd/application.yaml
kubectl -n argocd get application python-app
```

Check:

```bash
kubectl -n python-app get pods
kubectl -n python-app get ingress
kubectl -n python-app get svc
```

## Rollback

Preferred GitOps rollback:

1. Identify the last known-good Git commit.
2. Revert the bad GitOps image-tag commit.
3. Push the revert.
4. Argo CD automatically syncs the desired state.

For an emergency runtime rollback:

```bash
./scripts/rollback.sh
```

Note: a direct `kubectl rollout undo` is temporary from a GitOps perspective. Git remains the source of truth, so the Git repository should be corrected afterward.

## Shutdown

Application-only shutdown:

```bash
./scripts/shutdown.sh
```

This scales pods to zero and removes the Ingress, which allows the public ALB to be deleted.

For additional cost reduction, scale an EKS managed node group to zero:

```bash
./scripts/scale-nodegroup-to-zero.sh CLUSTER NODEGROUP ap-south-1
```

The EKS control plane still incurs charges. Verify AWS pricing for your account/region before choosing a shutdown strategy.

## Startup

Scale the node group back up:

```bash
./scripts/scale-nodegroup-up.sh CLUSTER NODEGROUP ap-south-1 2
```

Then:

```bash
kubectl get nodes
kubectl -n python-app get pods
kubectl -n python-app get ingress
```

Argo CD should restore the desired application state.

## Health checks

```bash
kubectl -n python-app get pods
kubectl -n python-app describe deployment python-app
kubectl -n python-app logs deployment/python-app
kubectl -n python-app get events --sort-by=.lastTimestamp
```
