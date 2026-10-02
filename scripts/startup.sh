#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-python-app}"

echo "Make sure EKS nodes are running before continuing."
kubectl -n "$NAMESPACE" scale deployment/python-app --replicas=2
kubectl -n "$NAMESPACE" apply -f argocd/application.yaml 2>/dev/null || true
kubectl -n "$NAMESPACE" rollout status deployment/python-app --timeout=5m || true

echo "Application startup requested."
echo "Argo CD should recreate the Ingress/ALB if it was deleted."
