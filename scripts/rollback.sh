#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-python-app}"
DEPLOYMENT="${2:-python-app}"

echo "Current deployment history:"
kubectl -n "$NAMESPACE" rollout history "deployment/$DEPLOYMENT"

echo
echo "Performing an emergency Kubernetes rollback..."
kubectl -n "$NAMESPACE" rollout undo "deployment/$DEPLOYMENT"
kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT" --timeout=5m

echo
echo "IMPORTANT: Git is the source of truth."
echo "If Argo CD automated sync is enabled, it may restore the Git-defined image."
echo "For a permanent rollback, revert the bad image-tag commit in Git and push it."
