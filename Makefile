SHELL := /usr/bin/env bash

TF_DIR ?= terraform/envs/rncp
KUBECONFIG_PATH ?= $(HOME)/devops/rncp/kubeconfig

.PHONY: help azure-env tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy outputs kubeconfig \
        argocd-forward argocd-pass grafana-forward prometheus-forward alertmanager-forward demo-up

help:
	@echo "Targets:"
	@echo "  azure-env            check Azure env (exports ARM_* via scripts/azure-env.sh)"
	@echo "  tf-init              terraform init"
	@echo "  tf-fmt               terraform fmt -recursive"
	@echo "  tf-validate          terraform validate"
	@echo "  tf-plan              terraform plan (with ARM_* env)"
	@echo "  tf-apply             terraform apply (with ARM_* env)"
	@echo "  tf-destroy           terraform destroy (with ARM_* env)"
	@echo "  outputs              show terraform outputs"
	@echo "  kubeconfig           fetch kubeconfig via az aks get-credentials"
	@echo "  argocd-forward       port-forward ArgoCD (http://localhost:8080)"
	@echo "  argocd-pass          print ArgoCD initial admin password"
	@echo "  grafana-forward      port-forward Grafana (http://localhost:3000)"
	@echo "  prometheus-forward   port-forward Prometheus (http://localhost:9090)"
	@echo "  alertmanager-forward port-forward Alert demo"
	@echo "  demo-up              apply + kubeconfig + print ArgoCD pass + start port-forward"

# Juste pour vérifier que le script fonctionne (utile en debug)
azure-env:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && echo "Azure env OK (ARM_SUBSCRIPTION_ID=$$ARM_SUBSCRIPTION_ID)"'

tf-init:
	terraform -chdir=$(TF_DIR) init

tf-fmt:
	terraform -chdir=$(TF_DIR) fmt -recursive

tf-validate:
	terraform -chdir=$(TF_DIR) validate

tf-plan:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) plan'

tf-apply:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) apply'

tf-destroy:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) destroy'

outputs:
	terraform -chdir=$(TF_DIR) output

kubeconfig:
	KUBECONFIG_PATH=$(KUBECONFIG_PATH) TF_DIR=$(TF_DIR) ./scripts/kubeconfig.sh

argocd-forward:
	./scripts/portforward-argocd.sh

argocd-pass:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath="{.data.password}" | base64 -d; echo

grafana-forward:
	./scripts/portforward-grafana.sh

prometheus-forward:
	./scripts/portforward-prometheus.sh

alertmanager-forward:
	./scripts/portforward-alertmanager.sh

# Démo "one command":
# - terraform apply
# - récup kubeconfig
# - affiche le password admin ArgoCD
# - démarre le port-forward ArgoCD (bloquant tant que tu ne Ctrl+C)
demo-up:
	@$(MAKE) tf-apply
	@$(MAKE) kubeconfig
	@echo ""
	@echo "ArgoCD URL: http://localhost:8080"
	@echo -n "ArgoCD admin password: "
	@$(MAKE) argocd-pass
	@echo ""
	@echo "Starting port-forward (Ctrl+C to stop)..."
	@$(MAKE) argocd-forward
