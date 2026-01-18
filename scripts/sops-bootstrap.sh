#!/usr/bin/env bash
set -euo pipefail

AGE_KEY_FILE="${AGE_KEY_FILE:-$HOME/devops/rncp/age.key}"

if [[ ! -f "$AGE_KEY_FILE" ]]; then
  echo "Missing Age key: $AGE_KEY_FILE"
  echo "Create it once: age-keygen -o $AGE_KEY_FILE && chmod 600 $AGE_KEY_FILE"
  exit 1
fi

chmod 600 "$AGE_KEY_FILE"

kubectl -n argocd create secret generic sops-age \
  --from-file=age.agekey="$AGE_KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Optionnel mais recommandé : restart repo-server pour recharger clean l'env / montage
kubectl -n argocd rollout restart deploy argocd-repo-server || true

echo "OK: secret sops-age applied in namespace argocd."
