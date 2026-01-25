#!/usr/bin/env bash
set -euo pipefail

NS="${1:-argocd}"

kubectl -n "$NS" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
