#!/usr/bin/env bash
set -euo pipefail
kubectl -n argocd port-forward svc/argocd-server 8080:80
