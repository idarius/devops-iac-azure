#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform/envs/rncp}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/devops/rncp/kubeconfig}"

mkdir -p "$(dirname "$KUBECONFIG_PATH")"
touch "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"

RG="$(terraform -chdir="$TF_DIR" output -raw resource_group_name)"
AKS="$(terraform -chdir="$TF_DIR" output -raw aks_name)"

az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing

echo "KUBECONFIG=$KUBECONFIG"
kubectl cluster-info
