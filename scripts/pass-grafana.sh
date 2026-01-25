#!/usr/bin/env bash
set -euo pipefail

NS="monitoring"
SECRET="monitoring-grafana"

# Si monitoring n'est pas encore déployé, on n'explose pas le make
if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
  echo "N/A (namespace ${NS} absent)"
  exit 0
fi

if ! kubectl -n "${NS}" get secret "${SECRET}" >/dev/null 2>&1; then
  echo "N/A (secret ${SECRET} absent)"
  exit 0
fi

kubectl -n "${NS}" get secret "${SECRET}" -o jsonpath='{.data.admin-password}' | base64 -d
echo
