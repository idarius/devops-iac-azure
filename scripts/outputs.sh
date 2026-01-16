#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform/envs/rncp}"
terraform -chdir="$TF_DIR" output