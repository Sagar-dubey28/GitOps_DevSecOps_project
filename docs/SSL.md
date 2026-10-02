# SSL/TLS Configuration

## Application

The application ALB uses AWS Certificate Manager (ACM).

1. Request/import a certificate in ACM for your hostname, for example:
   `python.example.com`
2. Complete DNS validation.
3. Put the certificate ARN into:
   `helm/python-app/values.yaml`
4. Put the hostname into `ingress.host`.
5. Commit and push.
6. Argo CD syncs the Ingress.
7. AWS Load Balancer Controller creates/updates the ALB.
8. Create the DNS CNAME/alias record after the ALB hostname is available.

HTTP is redirected to HTTPS by the ALB annotation.

## Argo CD UI

A production setup can expose Argo CD through a dedicated hostname such as:

`argocd.example.com`

Recommended pattern:

- AWS Load Balancer Controller
- ALB Ingress
- ACM certificate
- HTTPS listener
- DNS record

Example conceptual Ingress:

```yaml
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
    alb.ingress.kubernetes.io/certificate-arn: <ACM_CERTIFICATE_ARN>
spec:
  ingressClassName: alb
  rules:
    - host: argocd.example.com
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

For the assignment, DNS records are intentionally not created by this repository.
