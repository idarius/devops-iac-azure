SHELL := /usr/bin/env bash
MAKEFLAGS += --no-print-directory

TF_DIR ?= terraform/envs/rncp
KUBECONFIG_PATH ?= $(HOME)/devops/rncp/kubeconfig

.PHONY: tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy outputs kubeconfig sops-bootstrap \
        forward-argocd pass-argocd pass-grafana forward-grafana forward-prometheus forward-alertmanager \
		demo-up forward-all velero-bootstrap velero-backup-dev velero-backup-prod velero-backup-both \
		velero-restore-dev velero-restore-prod velero-restore-both


azure-env:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && echo "Azure env OK (ARM_SUBSCRIPTION_ID=$$ARM_SUBSCRIPTION_ID)"'

tf-init:
	@terraform -chdir=$(TF_DIR) init

tf-fmt:
	@terraform -chdir=$(TF_DIR) fmt -recursive

tf-validate:
	@terraform -chdir=$(TF_DIR) validate

tf-plan:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) plan'

tf-apply:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) apply'

tf-destroy:
	@bash -lc 'source ./scripts/azure-env.sh >/dev/null && terraform -chdir=$(TF_DIR) destroy'

outputs:
	@terraform -chdir=$(TF_DIR) output

kubeconfig:
	@KUBECONFIG_PATH=$(KUBECONFIG_PATH) TF_DIR=$(TF_DIR) ./scripts/kubeconfig.sh

sops-bootstrap:
	@AGE_KEY_FILE=$(HOME)/devops/rncp/age.key ./scripts/sops-bootstrap.sh

forward-argocd:
	@./scripts/portforward-argocd.sh

pass-argocd:
	@./scripts/pass-argocd.sh

pass-grafana:
	@./scripts/pass-grafana.sh

forward-grafana:
	@./scripts/portforward-grafana.sh

forward-prometheus:
	@./scripts/portforward-prometheus.sh

forward-alertmanager:
	@./scripts/portforward-alertmanager.sh

forward-all:
	@./scripts/portforward-all.sh

velero-bootstrap:
	@TF_DIR=$(TF_DIR) PLATFORM_REPO_DIR=$(HOME)/devops/devops-platform-k8s ./scripts/velero-bootstrap.sh

velero-backup-dev:
	@./scripts/velero-backup.sh dev

velero-backup-prod:
	@./scripts/velero-backup.sh prod

velero-backup-both:
	@./scripts/velero-backup.sh both

# usage: make velero-restore-dev BACKUP=bookstack-dev-manual-20260125-234510
velero-restore-dev:
	@test -n "$(BACKUP)" || (echo "BACKUP is required"; exit 1)
	WIPE=true ./scripts/velero-restore.sh "$(BACKUP)" dev

velero-restore-prod:
	@test -n "$(BACKUP)" || (echo "BACKUP is required"; exit 1)
	WIPE=true ./scripts/velero-restore.sh "$(BACKUP)" prod

velero-restore-both:
	@test -n "$(BACKUP)" || (echo "BACKUP is required"; exit 1)
	WIPE=true ./scripts/velero-restore.sh "$(BACKUP)" both

demo-up:
	@$(MAKE) tf-init
	@$(MAKE) tf-fmt
	@$(MAKE) tf-validate
	@$(MAKE) tf-apply
	@$(MAKE) kubeconfig
	@$(MAKE) sops-bootstrap
	@$(MAKE) velero-bootstrap
	@echo -n "ArgoCD admin password: "
	@$(MAKE) pass-argocd
	@echo -n "Grafana admin password: "
	@$(MAKE) pass-grafana
	@$(MAKE) forward-all

