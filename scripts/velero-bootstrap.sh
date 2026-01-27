#!/usr/bin/env bash
set -euo pipefail

# Répertoire Terraform pour la configuration Azure
TF_DIR="${TF_DIR:-terraform/envs/rncp}"

# Chemin local du dépôt platform-k8s ou seront générés les fichiers Velero
PLATFORM_REPO_DIR="${PLATFORM_REPO_DIR:-$HOME/devops/devops-platform-k8s}"

# Chemin du fichier secret Velero (chiffré avec SOPS)
VELERO_SECRET_REL="cluster/rncp-aks/platform/velero-secrets/cloud-credentials.secret.sops.yaml"
VELERO_SECRET="${PLATFORM_REPO_DIR}/${VELERO_SECRET_REL}"

# Chemin du fichier BackupStorageLocation (non sensible, pas chiffré)
VELERO_BSL_REL="cluster/rncp-aks/platform/velero-config/backupstoragelocation.yaml"
VELERO_BSL="${PLATFORM_REPO_DIR}/${VELERO_BSL_REL}"

# Dépendances requises
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1"; exit 1; }; }
need terraform
need sops
need git

# Le répertoire platform doit être un dépôt git pour le commit auto
if [[ ! -d "$PLATFORM_REPO_DIR/.git" ]]; then
  echo "ERROR: PLATFORM_REPO_DIR is not a git repo: $PLATFORM_REPO_DIR"
  exit 1
fi

# Helper pour récupérer un output Terraform
tfout() {
  terraform -chdir="$TF_DIR" output -raw "$1"
}

# On a besoin des outputs Terraform (donc init + apply faits)
if ! terraform -chdir="$TF_DIR" output >/dev/null 2>&1; then
  echo "ERROR: terraform outputs not available."
  echo "Check:"
  echo "  - TF_DIR is correct (currently: $TF_DIR)"
  echo "  - terraform init/apply has been run in that directory"
  exit 1
fi

# Récupération des valeurs Azure depuis les outputs Terraform
SUBSCRIPTION_ID="$(tfout subscription_id)"
TENANT_ID="$(tfout tenant_id)"
AKS_RESOURCE_GROUP="$(tfout resource_group_name)"
VELERO_CLIENT_ID="$(tfout velero_client_id)"
VELERO_CLIENT_SECRET="$(tfout velero_client_secret)"
VELERO_STORAGE_RG="$(tfout resource_group_name)"
VELERO_STORAGE_ACCOUNT="$(tfout storage_account_name)"
VELERO_BUCKET="$(tfout velero_container_name)"

cd "$PLATFORM_REPO_DIR"

# SOPS doit être configuré dans le repo pour chiffrer les secrets
if [[ ! -f ".sops.yaml" ]]; then
  echo "ERROR: .sops.yaml not found in $PLATFORM_REPO_DIR"
  exit 1
fi

# Génération du Secret Velero (sera chiffré avec SOPS)
TMP_PLAIN="$(mktemp -p . velero-cloud-credentials.XXXXXX.sops.yaml)"
TMP_ENC="$(mktemp -p . velero-cloud-credentials.XXXXXX.enc.sops.yaml)"

cat > "$TMP_PLAIN" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
    AZURE_TENANT_ID=${TENANT_ID}
    AZURE_CLIENT_ID=${VELERO_CLIENT_ID}
    AZURE_CLIENT_SECRET=${VELERO_CLIENT_SECRET}
    AZURE_RESOURCE_GROUP=${AKS_RESOURCE_GROUP}
    AZURE_CLOUD_NAME=AzurePublicCloud
EOF

sops -e "$TMP_PLAIN" > "$TMP_ENC"
rm -f "$TMP_PLAIN"

# Vérification que le fichier est bien chiffré avant de le commiter
if ! grep -qE '^sops:' "$TMP_ENC"; then
  echo "ERROR: encrypted output does not contain a top-level 'sops:' block."
  echo "Refusing to overwrite and push."
  rm -f "$TMP_ENC"
  exit 1
fi

if grep -qE 'AZURE_CLIENT_SECRET=' "$TMP_ENC"; then
  echo "ERROR: AZURE_CLIENT_SECRET appears in plaintext in the encrypted output."
  echo "Refusing to overwrite and push."
  rm -f "$TMP_ENC"
  exit 1
fi

mkdir -p "$(dirname "$VELERO_SECRET_REL")"
mv -f "$TMP_ENC" "$VELERO_SECRET_REL"

# Génération du BackupStorageLocation (pas de secrets, pas besoin de chiffrer)
mkdir -p "$(dirname "$VELERO_BSL_REL")"
cat > "$VELERO_BSL_REL" <<EOF
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: azure
  default: true
  objectStorage:
    bucket: ${VELERO_BUCKET}
  config:
    resourceGroup: ${VELERO_STORAGE_RG}
    storageAccount: ${VELERO_STORAGE_ACCOUNT}
    subscriptionId: ${SUBSCRIPTION_ID}
  credential:
    name: cloud-credentials
    key: cloud
EOF

# Commit et push vers platform-k8s
git add "$VELERO_SECRET_REL" "$VELERO_BSL_REL"

if git diff --cached --quiet; then
  echo "No velero change to commit."
else
  git commit -m "chore(velero): refresh cloud-credentials + BSL"
  git push
fi

echo "OK: velero secret (encrypted) + BSL (plain) generated and pushed."
