#!/usr/bin/env bash
set -euo pipefail

# Dossier terraform
TF_DIR="${TF_DIR:-terraform/envs/rncp}"

# Repo platform local
PLATFORM_REPO_DIR="${PLATFORM_REPO_DIR:-$HOME/devops/devops-platform-k8s}"

# Fichier cible dans le repo platform
VELERO_SECRET_REL="cluster/rncp-aks/platform/velero-secrets/cloud-credentials.secret.sops.yaml"
VELERO_SECRET="${PLATFORM_REPO_DIR}/${VELERO_SECRET_REL}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1"; exit 1; }; }
need terraform
need sops
need python3
need git

if [[ ! -d "$PLATFORM_REPO_DIR/.git" ]]; then
  echo "ERROR: PLATFORM_REPO_DIR is not a git repo: $PLATFORM_REPO_DIR"
  exit 1
fi

# ---- Terraform outputs ----
TMP_ERR="$(mktemp)"
TF_OUT_JSON="$(terraform -chdir="$TF_DIR" output -json 2>"$TMP_ERR" || true)"

if [[ -z "${TF_OUT_JSON// }" ]]; then
  echo "ERROR: terraform output -json returned empty output."
  echo "Terraform stderr was:"
  sed 's/^/  /' "$TMP_ERR" || true
  rm -f "$TMP_ERR"
  echo
  echo "Check:"
  echo "  - TF_DIR is correct (currently: $TF_DIR)"
  echo "  - terraform init/apply has been run in that directory"
  exit 1
fi
rm -f "$TMP_ERR"

# ---- extract output values ----
pyget() {
  python3 -c 'import json,sys; data=json.load(sys.stdin); print(data[sys.argv[1]]["value"])' "$1"
}

# ---- Required outputs ----
SUBSCRIPTION_ID="$(printf '%s' "$TF_OUT_JSON" | pyget subscription_id)"
TENANT_ID="$(printf '%s' "$TF_OUT_JSON" | pyget tenant_id)"
AKS_RESOURCE_GROUP="$(printf '%s' "$TF_OUT_JSON" | pyget resource_group_name)"
VELERO_CLIENT_ID="$(printf '%s' "$TF_OUT_JSON" | pyget velero_client_id)"
VELERO_CLIENT_SECRET="$(printf '%s' "$TF_OUT_JSON" | pyget velero_client_secret)"

# ---- Build plaintext + encrypt using repo .sops.yaml ----
cd "$PLATFORM_REPO_DIR"

if [[ ! -f ".sops.yaml" ]]; then
  echo "ERROR: .sops.yaml not found in $PLATFORM_REPO_DIR"
  exit 1
fi

# IMPORTANT:
# - temp files created INSIDE the repo so SOPS can find .sops.yaml
# - temp file name ends with .sops.yaml so it matches your creation_rules path_regex
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

# ---- Safety checks: ensure it's encrypted & no plaintext ----
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

# ---- Write final file ----
mkdir -p "$(dirname "$VELERO_SECRET_REL")"
mv -f "$TMP_ENC" "$VELERO_SECRET_REL"

# ---- Commit/push ----
git add "$VELERO_SECRET_REL"

if git diff --cached --quiet; then
  echo "No velero secret change to commit."
else
  git commit -m "chore(velero): refresh encrypted cloud-credentials"
  git push
fi

echo "OK: velero secret generated + encrypted (validated) + pushed."
