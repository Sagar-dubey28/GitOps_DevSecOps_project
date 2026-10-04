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
