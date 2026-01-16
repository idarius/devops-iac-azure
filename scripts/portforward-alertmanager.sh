#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093
