#!/usr/bin/env bash
set -euo pipefail
NS="${1:-monitoring}"
kubectl -n "$NS" get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo