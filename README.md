# devops-iac-azure

Infrastructure as Code pour déployer une plateforme GitOps sur Azure (AKS).

## Architecture

Ce projet déploie :
- Un cluster AKS mono-noeud
- Un registry ACR pour les images Docker
- Un Storage Account pour les backups Velero
- ArgoCD pré-configuré avec KSOPS (secrets chiffrés)
- L'authentification OIDC GitHub Actions → Azure (sans secrets statiques)

Le cluster est ensuite piloté par ArgoCD qui synchronise les manifests depuis :
- [devops-platform-k8s](https://github.com/idarius/devops-platform-k8s) → composants plateforme (Traefik, cert-manager, monitoring, Velero, external-dns)
- [devops-app-bookstack](https://github.com/idarius/devops-app-bookstack) → application de démo (BookStack + MariaDB)

## Prérequis

- Terraform >= 1.6
- Azure CLI connecté (`az login`)
- kubectl, helm, sops, age
- Un token GitHub (PAT) avec droits sur les repos

## Déploiement rapide

```bash
# Configurer les variables Azure
source scripts/azure-env.sh

# Déployer toute l'infra + récupérer kubeconfig + configurer SOPS + Velero
make demo-up
```

Le `make demo-up` enchaîne :
1. `tf-init` / `tf-apply` → déploie l'infra Azure + ArgoCD
2. `kubeconfig` → récupère le kubeconfig dans `~/devops/rncp/`
3. `sops-bootstrap` → injecte la clé Age dans ArgoCD pour déchiffrer les secrets
4. `velero-bootstrap` → génère et push les credentials Velero (chiffrés) dans le repo platform

## Structure Terraform

```
terraform/envs/rncp/
├── 00-versions.tf          # Providers requis
├── 05-variables.tf         # Variables (tailles VM, IPs autorisées, etc.)
├── 10-providers.tf         # Config providers Azure/GitHub/Helm
├── 20-locals.tf            # Nommage dynamique
├── 30-rg.tf                # Resource Group
├── 40-acr.tf               # Container Registry
├── 50-storage-velero.tf    # Storage Account + container blob
├── 60-aks.tf               # Cluster AKS
├── 70-iam.tf               # Rôle AKS → ACR (pull images)
├── 71-oidc-github-actions.tf  # Fédération OIDC GitHub → Azure
├── 72-github-actions-variables.tf  # Variables injectées dans GitHub Actions
├── 73-iam-velero.tf        # Service Principal Velero
├── 80-argocd.tf            # Helm release ArgoCD + KSOPS
├── 81-argocd-apps.tf       # App-of-Apps (bootstrap)
└── 90-outputs.tf           # Outputs (noms, IDs, secrets)
```

## Commandes Make

| Commande | Description |
|----------|-------------|
| `make tf-plan` | Prévisualise les changements |
| `make tf-apply` | Applique l'infrastructure |
| `make tf-destroy` | Détruit tout |
| `make kubeconfig` | Récupère le kubeconfig |
| `make sops-bootstrap` | Configure SOPS dans ArgoCD |
| `make velero-bootstrap` | Génère les credentials Velero |
| `make forward-argocd` | Port-forward ArgoCD (localhost:8080) |
| `make forward-grafana` | Port-forward Grafana (localhost:3000) |
| `make pass-argocd` | Affiche le mot de passe admin ArgoCD |
| `make pass-grafana` | Affiche le mot de passe admin Grafana |
| `make velero-backup-dev` | Backup manuel namespace dev |
| `make velero-restore-dev BACKUP=<name>` | Restore namespace dev |

## Sécurité

- **API AKS** : publique mais restreinte par whitelist IP (variable `aks_api_authorized_ip_ranges`)
- **Secrets** : chiffrés avec SOPS/Age, jamais en clair dans Git
- **GitHub Actions** : authentification OIDC, pas de secrets statiques
- **ACR** : accès AKS via Managed Identity

## Après déploiement

Une fois `make demo-up` terminé :
1. ArgoCD synchronise automatiquement les composants plateforme
2. Les apps BookStack (dev/prod) se déploient via les manifests du repo app
3. External-DNS crée les entrées DNS dans Cloudflare
4. Cert-manager génère les certificats Let's Encrypt

Accès :
- ArgoCD : `make forward-argocd` → https://localhost:8080
- Grafana : `make forward-grafana` → http://localhost:3000
- BookStack dev : https://bookstackdev.rncp.idarius.net
- BookStack prod : https://bookstackprod.rncp.idarius.net
