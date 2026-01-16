SHELL := /usr/bin/env bash

TF_DIR ?= terraform/envs/rncp
KUBECONFIG_PATH ?= $(HOME)/devops/rncp/kubeconfig

.PHONY: help tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy outputs kubeconfig \
        argocd-forward argocd-pass grafana-forward prometheus-forward alertmanager-forward

help:
	@echo "Targets:"
	@echo "  tf-init            terraform init"
	@echo "  tf-fmt             terraform fmt -recursive"
	@echo "  tf-validate        terraform validate"
	@echo "  tf-plan            terraform plan"
	@echo "  tf-apply           terraform apply"
	@echo "  tf-destroy         terraform destroy"
	@echo "  outputs            show terraform outputs"
	@echo "  kubeconfig         fetch kubeconfig via az aks get-credentials"
	@echo "  argocd-forward     port-forward ArgoCD (http://localhost:8080)"
	@echo "  argocd-pass        print ArgoCD initial admin password"
	@echo "  grafana-forward    port-forward Grafana (http://localhost:3000)"
	@echo "  prometheus-forward port-forward Prometheus (http://localhost:9090)"
	@echo "  alertmanager-forward port-forward Alertmanager (http://localhost:9093)"

tf-init:
	terraform -chdir=$(TF_DIR) init

tf-fmt:
	terraform -chdir=$(TF_DIR) fmt -recursive

tf-validate:
	terraform -chdir=$(TF_DIR) validate

tf-plan:
	terraform -chdir=$(TF_DIR) plan

tf-apply:
	terraform -chdir=$(TF_DIR) apply

tf-destroy:
	terraform -chdir=$(TF_DIR) destroy

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
