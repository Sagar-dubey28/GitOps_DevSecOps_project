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
