#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform/envs/rncp}"
PLATFORM_REPO_DIR="${PLATFORM_REPO_DIR:-$HOME/devops/devops-platform-k8s}"

VELERO_SECRET_REL="cluster/rncp-aks/platform/velero-secrets/cloud-credentials.secret.sops.yaml"
VELERO_SECRET="${PLATFORM_REPO_DIR}/${VELERO_SECRET_REL}"

command -v terraform >/dev/null
command -v sops >/dev/null
command -v python3 >/dev/null
command -v git >/dev/null

if [[ ! -d "$PLATFORM_REPO_DIR/.git" ]]; then
  echo "ERROR: PLATFORM_REPO_DIR is not a git repo: $PLATFORM_REPO_DIR"
  exit 1
fi

TF_OUT_JSON="$(terraform -chdir="$TF_DIR" output -json)"

pyget() {
  python3 - "$1" <<'PY'
import json,sys
data=json.loads(sys.stdin.read())
key=sys.argv[1]
v=data[key]["value"]
if isinstance(v,(dict,list)):
  import json as j
  print(j.dumps(v))
else:
  print(v)
PY
}

SUBSCRIPTION_ID="$(printf '%s' "$TF_OUT_JSON" | pyget subscription_id)"
TENANT_ID="$(printf '%s' "$TF_OUT_JSON" | pyget tenant_id)"
AKS_RESOURCE_GROUP="$(printf '%s' "$TF_OUT_JSON" | pyget resource_group_name)"
VELERO_CLIENT_ID="$(printf '%s' "$TF_OUT_JSON" | pyget velero_client_id)"
VELERO_CLIENT_SECRET="$(printf '%s' "$TF_OUT_JSON" | pyget velero_client_secret)"

# 1) Génère le secret en clair dans un tmp
TMP_PLAIN="$(mktemp)"
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

# 2) Chiffre dans un tmp, sans toucher au fichier final
TMP_ENC="$(mktemp)"
(
  cd "$PLATFORM_REPO_DIR"
  sops -e "$TMP_PLAIN" > "$TMP_ENC"
)

rm -f "$TMP_PLAIN"

# 3) Garde fou anti secret en clair
# - on exige un bloc "sops:"
# - on refuse si on voit AZURE_CLIENT_SECRET= en clair
if ! grep -qE '^sops:' "$TMP_ENC"; then
  echo "ERROR: encrypted file does not contain a top-level 'sops:' block."
  echo "Refusing to overwrite and push."
  rm -f "$TMP_ENC"
  exit 1
fi

if grep -qE 'AZURE_CLIENT_SECRET=' "$TMP_ENC"; then
  echo "ERROR: looks like AZURE_CLIENT_SECRET is present in plaintext in the encrypted output."
  echo "Refusing to overwrite and push."
  rm -f "$TMP_ENC"
  exit 1
fi

# 4) Écrit le fichier final seulement si tout est OK
mkdir -p "$(dirname "$VELERO_SECRET")"
mv -f "$TMP_ENC" "$VELERO_SECRET"

# 5) Commit/push uniquement ce fichier
cd "$PLATFORM_REPO_DIR"
git add "$VELERO_SECRET_REL"

if git diff --cached --quiet; then
  echo "No velero secret change to commit."
else
  git commit -m "chore(velero): refresh encrypted cloud-credentials"
  git push
fi

echo "OK: velero secret generated + encrypted (validated) + pushed."
