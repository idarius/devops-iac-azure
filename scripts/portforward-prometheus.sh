#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
