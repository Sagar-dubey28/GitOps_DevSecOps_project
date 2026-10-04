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
