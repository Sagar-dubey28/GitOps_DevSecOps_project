#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-python-app}"

echo "Current rollout:"
kubectl -n "$NAMESPACE" rollout history deployment/python-app

echo "Rolling back to the previous Kubernetes revision..."
kubectl -n "$NAMESPACE" rollout undo deployment/python-app
kubectl -n "$NAMESPACE" rollout status deployment/python-app

echo "Rollback completed."
