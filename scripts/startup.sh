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
