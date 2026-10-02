# Security Controls

## CI/CD

- Python dependency installation is pinned in `requirements.txt`.
- Trivy filesystem scan blocks HIGH/CRITICAL vulnerabilities when fixable.
- Trivy container scan blocks HIGH/CRITICAL vulnerabilities when fixable.
- Container uses a non-root user.
- Container drops Linux capabilities.
- Privilege escalation is disabled.
- Root filesystem is read-only; `/tmp` uses an `emptyDir`.
- Image tags use the immutable Git SHA rather than `latest`.

## AWS credentials

For a production GitHub setup, prefer GitHub OIDC with an AWS IAM role rather than long-lived access keys.

The included workflow uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` only as a simple fallback for an assignment. If you use them, store them only in GitHub Actions Secrets.

Recommended permissions for the deployment identity should be limited to:
- ECR push/pull operations required by CI
- GitHub repository contents write for the GitOps commit

Argo CD should use an IAM/Kubernetes identity with only the permissions required to deploy this namespace.

## TLS

The application Ingress uses an ACM certificate ARN. The certificate must cover the hostname in `helm/python-app/values.yaml`.

Argo CD UI TLS can be exposed through a separate Ingress using an ACM certificate. DNS records are intentionally left as placeholders because DNS changes are handled separately.

## Kubernetes

- Readiness/liveness probes are configured.
- Resource requests and limits are configured.
- HPA is enabled.
- PDB protects availability during voluntary disruptions.
- Rolling updates use `maxUnavailable: 0`.
