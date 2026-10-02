# Argo CD

Update `application.yaml` with your GitHub repository URL, then:

```bash
kubectl apply -f argocd/application.yaml
```

Argo CD watches the `main` branch. The GitHub Actions workflow builds and scans the image, pushes it to ECR, then updates `helm/python-app/values.yaml` with the immutable image tag. Argo CD detects that Git change and deploys it to EKS.
