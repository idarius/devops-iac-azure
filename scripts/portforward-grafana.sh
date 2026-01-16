#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
