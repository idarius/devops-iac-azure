#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Script de création de sauvegardes Velero pour les environnements Kubernetes
################################################################################
#
# USAGE:
#   ./scripts/velero-backup.sh dev     # Sauvegarde l'environnement de dev
#   ./scripts/velero-backup.sh prod    # Sauvegarde l'environnement de prod
#   ./scripts/velero-backup.sh both    # Sauvegarde les deux environnements
#
# VARIABLES D'ENVIRONNEMENT :
#   VELERO_NS       - Namespace où Velero est installé (défaut: velero)
#   DEV_NS          - Namespace de développement (défaut: bookstack-dev)
#   PROD_NS         - Namespace de production (défaut: bookstack-prod)
#   TTL             - Durée de rétention du backup (défaut: 72h0m0s)
#   WAIT            - Attendre la fin du backup (défaut: true)

VELERO_NS="${VELERO_NS:-velero}"
DEV_NS="${DEV_NS:-bookstack-dev}"
PROD_NS="${PROD_NS:-bookstack-prod}"
TTL="${TTL:-72h0m0s}"
WAIT="${WAIT:-true}"

# Vérifier qu'une commande est disponible dans le PATH
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1"; exit 1; }
}

need kubectl

# Récupérer le mode (dev|prod|both) passé en paramètre
mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "Usage: $0 dev|prod|both"
  exit 1
fi

# Générer un timestamp unique pour identifier le backup (format: YYYYMMDD-HHMMSS)
ts="$(date +%Y%m%d-%H%M%S)"

# Déterminer le nom du backup et les namespaces à sauvegarder
case "$mode" in
  dev)
    name="bookstack-dev-manual-${ts}"
    namespaces=("$DEV_NS")
    ;;
  prod)
    name="bookstack-prod-manual-${ts}"
    namespaces=("$PROD_NS")
    ;;
  both)
    name="bookstack-both-manual-${ts}"
    namespaces=("$DEV_NS" "$PROD_NS")
    ;;
  *)
    echo "ERROR: invalid mode '$mode' (expected dev|prod|both)"
    exit 1
    ;;
esac

# Créer la ressource Velero Backup
echo "Creating Velero backup: ${name}"
kubectl -n "$VELERO_NS" apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${name}
  namespace: ${VELERO_NS}
spec:
  ttl: ${TTL}
  includedNamespaces:
$(for ns in "${namespaces[@]}"; do echo "    - ${ns}"; done)
  defaultVolumesToFsBackup: true
EOF

echo "Backup created. Status:"
kubectl -n "$VELERO_NS" get backup "$name" -o wide || true

# Attendre la fin du backup si WAIT=true
if [[ "$WAIT" == "true" ]]; then
  echo "Waiting for completion..."
  while true; do
    phase="$(kubectl -n "$VELERO_NS" get backup "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ -z "$phase" ]] && phase="(pending)"
    echo "  phase=${phase}"
    case "$phase" in
      Completed)
        echo "OK: backup completed: ${name}"
        break
        ;;
      Failed|PartiallyFailed)
        echo "ERROR: backup ended with phase=${phase}"
        kubectl -n "$VELERO_NS" describe backup "$name" || true
        exit 2
        ;;
      *)
        sleep 3
        ;;
    esac
  done
fi

echo "Tip: Azure Blob should now contain backups/${name}/"
