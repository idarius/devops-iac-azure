#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/velero-restore.sh <backupName> dev
#   ./scripts/velero-restore.sh <backupName> prod
#   ./scripts/velero-restore.sh <backupName> both
#
# Env vars:
#   VELERO_NS=velero
#   DEV_NS=bookstack-dev
#   PROD_NS=bookstack-prod
#   WIPE=true|false   (delete namespace(s) before restore)
#   WAIT=true|false

VELERO_NS="${VELERO_NS:-velero}"
DEV_NS="${DEV_NS:-bookstack-dev}"
PROD_NS="${PROD_NS:-bookstack-prod}"
WIPE="${WIPE:-false}"
WAIT="${WAIT:-true}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1"; exit 1; }; }
need kubectl

backup="${1:-}"
mode="${2:-}"

if [[ -z "$backup" || -z "$mode" ]]; then
  echo "Usage: $0 <backupName> dev|prod|both"
  exit 1
fi

# verify backup exists
if ! kubectl -n "$VELERO_NS" get backup "$backup" >/dev/null 2>&1; then
  echo "ERROR: backup '${backup}' not found in namespace '${VELERO_NS}'"
  echo "Available backups:"
  kubectl -n "$VELERO_NS" get backups || true
  exit 2
fi

case "$mode" in
  dev)
    namespaces=("$DEV_NS")
    ;;
  prod)
    namespaces=("$PROD_NS")
    ;;
  both)
    namespaces=("$DEV_NS" "$PROD_NS")
    ;;
  *)
    echo "ERROR: invalid mode '$mode' (expected dev|prod|both)"
    exit 1
    ;;
esac

if [[ "$WIPE" == "true" ]]; then
  for ns in "${namespaces[@]}"; do
    echo "Wiping namespace: ${ns}"
    kubectl delete ns "$ns" --ignore-not-found
    # wait for deletion
    for i in {1..120}; do
      if kubectl get ns "$ns" >/dev/null 2>&1; then
        sleep 2
      else
        echo "  namespace deleted: ${ns}"
        break
      fi
    done
  done
fi

ts="$(date +%Y%m%d-%H%M%S)"
restore="restore-${backup}-${ts}"

echo "Creating Velero restore: ${restore} (from backup: ${backup})"
kubectl -n "$VELERO_NS" apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${restore}
  namespace: ${VELERO_NS}
spec:
  backupName: ${backup}
  includedNamespaces:
$(for ns in "${namespaces[@]}"; do echo "    - ${ns}"; done)
EOF

echo "Restore created. Status:"
kubectl -n "$VELERO_NS" get restore "$restore" -o wide || true

if [[ "$WAIT" == "true" ]]; then
  echo "Waiting for completion..."
  while true; do
    phase="$(kubectl -n "$VELERO_NS" get restore "$restore" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ -z "$phase" ]] && phase="(pending)"
    echo "  phase=${phase}"
    case "$phase" in
      Completed)
        echo "OK: restore completed: ${restore}"
        break
        ;;
      Failed|PartiallyFailed)
        echo "ERROR: restore ended with phase=${phase}"
        kubectl -n "$VELERO_NS" describe restore "$restore" || true
        exit 3
        ;;
      *)
        sleep 3
        ;;
    esac
  done
fi

echo "Post-checks:"
for ns in "${namespaces[@]}"; do
  echo "== ${ns} =="
  kubectl get ns "$ns" || true
  kubectl -n "$ns" get pvc || true
  kubectl -n "$ns" get pods || true
done
