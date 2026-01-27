#!/usr/bin/env bash
set -euo pipefail

NS="monitoring"
SECRET="monitoring-grafana"

# Skip si le namespace monitoring n'existe pas encore
if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
  echo "N/A (namespace ${NS} absent)"
  exit 0
fi

# Skip si le secret n'existe pas encore
if ! kubectl -n "${NS}" get secret "${SECRET}" >/dev/null 2>&1; then
  echo "N/A (secret ${SECRET} absent)"
  exit 0
fi

# Extrait et décode le mot de passe admin depuis le secret
kubectl -n "${NS}" get secret "${SECRET}" -o jsonpath='{.data.admin-password}' | base64 -d
echo
