#!/usr/bin/env bash
set -euo pipefail

# etre sur d etre bien log sur azure
az account show >/dev/null

export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"

# Optionnel mais aide certains contextes
export ARM_USE_AZUREAD=true

export TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"

echo "ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID"
echo "ARM_TENANT_ID=$ARM_TENANT_ID"
