#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:?Usage: $0 <cluster-name> <nodegroup-name> [region] [desired]}"
NODEGROUP="${2:?Usage: $0 <cluster-name> <nodegroup-name> [region] [desired]}"
REGION="${3:-ap-south-1}"
DESIRED="${4:-2}"

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --scaling-config minSize=1,maxSize=3,desiredSize="$DESIRED" \
  --region "$REGION"

echo "Managed node group startup requested."
