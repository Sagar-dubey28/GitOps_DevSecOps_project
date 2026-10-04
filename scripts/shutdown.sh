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
