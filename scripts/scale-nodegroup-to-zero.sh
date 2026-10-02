#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:?Usage: $0 <cluster-name> <nodegroup-name> <region>}"
NODEGROUP="${2:?Usage: $0 <cluster-name> <nodegroup-name> <region>}"
REGION="${3:-ap-south-1}"

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region "$REGION"

echo "Node group scaled to zero. EKS control-plane charges remain."
