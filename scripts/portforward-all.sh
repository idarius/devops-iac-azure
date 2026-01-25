#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${LOG_DIR:-/tmp}"
pids=()

cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

start_pf() {
  local ns="$1"
  local target="$2"
  local mapping="$3"
  local logfile="$LOG_DIR/pf-${ns}-${target//\//-}.log"

  kubectl -n "$ns" port-forward "$target" "$mapping" >"$logfile" 2>&1 &
  local pid="$!"
  pids+=("$pid")

  sleep 0.3
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Port-forward FAILED: $ns $target ($mapping)"
    echo "Log: $logfile"
    tail -n 50 "$logfile" || true
    exit 1
  fi
}

start_pf argocd     svc/argocd-server 8080:80
start_pf monitoring svc/monitoring-grafana 3000:80
start_pf monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
start_pf monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093

echo "ArgoCD:       http://localhost:8080"
echo "Grafana:      http://localhost:3000"
echo "Prometheus:   http://localhost:9090"
echo "Alertmanager: http://localhost:9093"
echo "Ctrl+C pour stop."

wait
