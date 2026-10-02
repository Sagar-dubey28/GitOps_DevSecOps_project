#!/usr/bin/env bash
set -euo pipefail

# Cost-saving application shutdown.
# This removes the public ALB by deleting the Ingress and scales the workload to zero.
# EKS control-plane charges still apply while the cluster exists.
NAMESPACE="${1:-python-app}"

kubectl -n "$NAMESPACE" scale deployment/python-app --replicas=0 || true
kubectl -n "$NAMESPACE" delete ingress python-app --ignore-not-found

echo "Application stopped and public ALB ingress removed."
echo "To save more, scale the EKS managed node group to 0 desired nodes."
