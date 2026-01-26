# Architecture du projet GitOps

Documentation technique du projet de plateforme GitOps déployée sur Azure Kubernetes Service.

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Infrastructure Azure](#2-infrastructure-azure)
3. [Plateforme Kubernetes](#3-plateforme-kubernetes)
4. [Application BookStack](#4-application-bookstack)
5. [Décisions techniques](#5-décisions-techniques)

---

## 1. Vue d'ensemble

### 1.1 Objectif du projet

Mise en place d'une plateforme GitOps complète permettant de :
- Déployer une infrastructure cloud reproductible via Infrastructure as Code
- Gérer le cycle de vie d'applications conteneurisées (CI/CD)
- Assurer la disponibilité et l'observabilité des services
- Garantir la résilience via des backups automatisés

### 1.2 Architecture globale

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  GITHUB                                     │
│  ┌─────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐  │
│  │ devops-iac-azure│  │ devops-platform-k8s │  │ devops-app-bookstack    │  │
│  │ (Terraform)     │  │ (Manifests K8s)     │  │ (App + CI/CD)           │  │
│  └────────┬────────┘  └──────────┬──────────┘  └────────────┬────────────┘  │
└───────────┼──────────────────────┼──────────────────────────┼───────────────┘
            │                      │                          │
            │ terraform apply      │ sync                     │ push image
            ▼                      ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  AZURE                                      │
│                                                                             │
│  ┌──────────────┐    ┌──────────────────────────────────────────────────┐   │
│  │     ACR      │◄───│                     AKS                          │   │
│  │ (Registry)   │    │  ┌─────────────────────────────────────────────┐ │   │
│  └──────────────┘    │  │                  ArgoCD                     │ │   │
│                      │  │  (synchronise platform + apps depuis Git)   │ │   │
│  ┌──────────────┐    │  └─────────────────────────────────────────────┘ │   │
│  │   Storage    │    │                                                  │   │
│  │   Account    │◄───│  ┌───────────┐ ┌───────────┐ ┌───────────────┐   │   │
│  │  (Backups)   │    │  │  Traefik  │ │ Monitoring│ │    Velero     │   │   │
│  └──────────────┘    │  └───────────┘ └───────────┘ └───────────────┘   │   │
│                      │                                                  │   │
│                      │  ┌─────────────────┐  ┌─────────────────┐        │   │
│                      │  │  bookstack-dev  │  │  bookstack-prod │        │   │
│                      │  └─────────────────┘  └─────────────────┘        │   │
│                      └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               CLOUDFLARE                                    │
│         DNS automatique (external-dns) + Proxy/CDN optionnel                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Repositories

| Repository | Rôle | Contenu |
|------------|------|---------|
| devops-iac-azure | Infrastructure as Code | Terraform, scripts d'automatisation |
| devops-platform-k8s | Configuration plateforme | Manifests ArgoCD, Helm values, secrets chiffrés |
| devops-app-bookstack | Application métier | Dockerfile, manifests Kustomize, workflows CI/CD |

### 1.4 Technologies utilisées

| Domaine | Technologie | Version |
|---------|-------------|---------|
| Cloud | Azure (AKS, ACR, Storage) | - |
| IaC | Terraform | >= 1.6 |
| Orchestration | Kubernetes | 1.29+ |
| GitOps | ArgoCD | 3.2.5 |
| Ingress | Traefik | 38.0.2 |
| Certificats | cert-manager + Let's Encrypt | - |
| DNS | external-dns + Cloudflare | 1.19.0 |
| Monitoring | Prometheus + Grafana + Alertmanager | 81.0.0 |
| Backups | Velero | 11.3.2 |
| Secrets | SOPS + Age | - |
| CI/CD | GitHub Actions | - |

---

## 2. Infrastructure Azure

### 2.1 Ressources déployées

Le code Terraform déploie les ressources suivantes :

**Resource Group**
- Conteneur logique pour toutes les ressources
- Nommage : `idarius-rncp-rg-<suffix>`

**Azure Kubernetes Service (AKS)**
- Cluster Kubernetes managé
- Configuration mono-noeud (Standard_B2s_v2)
- Network plugin : Azure CNI
- Identité : System Assigned Managed Identity

**Azure Container Registry (ACR)**
- Registry privé pour les images Docker
- SKU : Basic
- Intégration AKS via rôle AcrPull

**Storage Account**
- Stockage objet pour les backups Velero
- Container blob dédié
- Accès via Service Principal

### 2.2 Organisation du code Terraform

```
terraform/envs/rncp/
├── 00-versions.tf          # Contraintes de versions providers
├── 05-variables.tf         # Variables d'entrée
├── 10-providers.tf         # Configuration des providers
├── 20-locals.tf            # Variables locales et nommage
├── 30-rg.tf                # Resource Group
├── 40-acr.tf               # Container Registry
├── 50-storage-velero.tf    # Storage pour backups
├── 60-aks.tf               # Cluster Kubernetes
├── 70-iam.tf               # Rôle AKS → ACR
├── 71-oidc-github-actions.tf   # Fédération OIDC
├── 72-github-actions-variables.tf  # Variables GitHub
├── 73-iam-velero.tf        # Service Principal Velero
├── 80-argocd.tf            # Déploiement ArgoCD via Helm
├── 81-argocd-apps.tf       # Bootstrap App-of-Apps
└── 90-outputs.tf           # Outputs
```

### 2.3 Sécurité de l'infrastructure

**Accès à l'API Kubernetes**
- API publique avec whitelist IP configurable
- Variable `aks_api_authorized_ip_ranges` permet de restreindre l'accès
- Désactivable pour les phases de démo

**Authentification GitHub Actions → Azure**
- Fédération OIDC (OpenID Connect)
- Pas de secrets statiques stockés dans GitHub
- Le workflow GitHub obtient un token éphémère auprès d'Azure AD
- Scope limité : uniquement push vers ACR

```
GitHub Actions                    Azure AD
     │                               │
     │ 1. Demande token OIDC         │
     ├──────────────────────────────►│
     │                               │
     │ 2. Vérifie issuer + subject   │
     │◄──────────────────────────────┤
     │                               │
     │ 3. Retourne access token      │
     │◄──────────────────────────────┤
     │                               │
     │ 4. Utilise token pour ACR     │
     └──────────────────────────────►│
```

**Accès AKS → ACR**
- Managed Identity du cluster
- Rôle `AcrPull` assigné automatiquement
- Pas de credentials à gérer

**Accès Velero → Storage**
- Service Principal dédié
- Rôle `Storage Blob Data Contributor`
- Secret généré par Terraform, chiffré avec SOPS avant stockage Git

### 2.4 Déploiement d'ArgoCD via Terraform

ArgoCD est déployé directement par Terraform (provider Helm) plutôt que manuellement. Cela garantit :
- Un état initial reproductible
- La configuration KSOPS intégrée dès le départ
- Le bootstrap automatique de l'App-of-Apps

Configuration KSOPS dans ArgoCD :
```yaml
repoServer:
  initContainers:
    - name: install-ksops
      # Télécharge et vérifie le binaire KSOPS (SHA256)
  volumeMounts:
    - name: sops-age
      mountPath: /.config/sops/age
  env:
    - name: SOPS_AGE_KEY_FILE
      value: /.config/sops/age/age.agekey
```

---

## 3. Plateforme Kubernetes

### 3.1 Pattern App-of-Apps

ArgoCD utilise le pattern "App-of-Apps" pour bootstrapper la plateforme :

```
                    ┌─────────────────┐
                    │  platform-root  │  (déployé par Terraform)
                    │   Application   │
                    └────────┬────────┘
                             │ découvre
                             ▼
        ┌────────────────────────────────────────┐
        │     cluster/rncp-aks/                  │
        │  ├── projects/*.yaml                   │
        │  ├── platform/*/application.yaml       │
        │  └── apps/*/application.yaml           │
        └────────────────────────────────────────┘
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │   traefik   │  │  monitoring │  │ bookstack-  │
    │ Application │  │ Application │  │     dev     │
    └─────────────┘  └─────────────┘  └─────────────┘
```

L'Application racine scanne le répertoire et crée automatiquement les Applications enfants.

### 3.2 AppProjects

Deux projets ArgoCD isolent les droits :

**platform** (composants infrastructure)
- Sources autorisées : repos Helm officiels (Traefik, Prometheus, etc.)
- Destinations : namespaces système (traefik, monitoring, velero, cert-manager)
- Cluster resources : CRDs, RBAC, Webhooks

**apps** (applications métier)
- Sources autorisées : repo devops-app-bookstack uniquement
- Destinations : namespaces applicatifs (bookstack-dev, bookstack-prod)
- Cluster resources : Namespace uniquement

### 3.3 Composants plateforme

#### Traefik (Ingress Controller)

- Déployé en LoadBalancer (IP publique Azure)
- Redirection HTTP → HTTPS automatique
- Entrypoints : web (80), websecure (443)
- Dashboard désactivé (sécurité)

```yaml
additionalArguments:
  - "--entryPoints.web.http.redirections.entryPoint.to=websecure"
  - "--entryPoints.web.http.redirections.entryPoint.scheme=https"
```

#### cert-manager

Gestion automatique des certificats TLS :

1. Un Ingress est créé avec l'annotation `cert-manager.io/cluster-issuer`
2. cert-manager détecte l'Ingress et crée une demande de certificat
3. Challenge DNS-01 via API Cloudflare
4. Certificat stocké dans un Secret Kubernetes
5. Traefik utilise le Secret pour le TLS

ClusterIssuers configurés :
- `letsencrypt-staging` : tests (pas de rate limit)
- `letsencrypt-prod` : production

#### external-dns

Synchronisation automatique des enregistrements DNS :

1. Surveille les ressources Ingress
2. Extrait les hostnames
3. Crée/met à jour les enregistrements A dans Cloudflare
4. Enregistrement TXT pour le ownership

Configuration :
```yaml
sources:
  - ingress
domainFilters:
  - idarius.net
policy: upsert-only    # Ne supprime jamais
txtOwnerId: aks-rncp   # Identifie ce cluster
```

#### Monitoring

Stack kube-prometheus-stack déployant :

**Prometheus**
- Scrape interval : 60s
- Retention : 6h (environnement de démo)
- Stockage : emptyDir (non persistant)

**Grafana**
- Dashboards chargés depuis ConfigMaps (sidecar)
- 4 dashboards custom : Kubernetes Overview, Nodes, Pods, BookStack
- Pas de persistance (dashboards dans Git)

**Alertmanager**
- Routing par severity
- Notifications email (Gmail SMTP)
- Alertes configurées :
  - BookStackDevDown / BookStackProdDown
  - MariaDBDevDown / MariaDBProdDown

Flux d'une alerte :
```
Prometheus          Alertmanager         Gmail
    │                    │                 │
    │ 1. Évalue règle    │                 │
    │    (for: 2m)       │                 │
    │                    │                 │
    │ 2. Envoie alerte   │                 │
    ├───────────────────►│                 │
    │                    │                 │
    │                    │ 3. Route selon  │
    │                    │    severity     │
    │                    │                 │
    │                    │ 4. Envoie email │
    │                    ├────────────────►│
    │                    │                 │
```

#### Velero

Backup et restauration des namespaces applicatifs.

**Composants** :
- Velero server : orchestration des backups
- Node Agent (DaemonSet) : backup des volumes (Restic/Kopia)
- Plugin Azure : intégration Storage Account

**Configuration** :
- BackupStorageLocation : pointe vers le container blob Azure
- Schedule : backup quotidien à 2h (retention 7 jours)
- Scope : namespaces bookstack-dev et bookstack-prod

**Processus de backup** :
1. Velero snapshot les ressources Kubernetes (YAML)
2. Node Agent backup les données des PVC
3. Tout est uploadé dans Azure Blob Storage

**Processus de restore** :
1. Suppression du namespace (optionnel, via WIPE=true)
2. Velero recrée les ressources depuis le backup
3. Node Agent restore les données des PVC
4. Les pods redémarrent avec leurs données

### 3.4 Gestion des secrets

Tous les secrets sont chiffrés avec SOPS (Age) avant d'être commités dans Git.

**Workflow de chiffrement** :
```bash
# Création d'un secret
cat > secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mon-secret
stringData:
  password: "valeur-sensible"
EOF

# Chiffrement
sops -e secret.yaml > secret.secret.sops.yaml
rm secret.yaml
git add secret.secret.sops.yaml
```

**Déchiffrement par ArgoCD** :
1. ArgoCD clone le repo
2. Kustomize détecte le générateur KSOPS
3. KSOPS appelle SOPS avec la clé Age montée
4. Le Secret déchiffré est appliqué dans le cluster

La clé Age privée est injectée dans ArgoCD via le script `sops-bootstrap.sh` :
```bash
kubectl -n argocd create secret generic sops-age \
  --from-file=age.agekey="$AGE_KEY_FILE"
```

---

## 4. Application BookStack

### 4.1 Architecture applicative

```
                    Ingress (Traefik)
                           │
                           ▼
┌──────────────────────────────────────────┐
│         Namespace bookstack-dev          │
│                                          │
│  ┌─────────────┐       ┌─────────────┐   │
│  │  BookStack  │──────►│   MariaDB   │   │
│  │   (PHP)     │       │   (MySQL)   │   │
│  └──────┬──────┘       └──────┬──────┘   │
│         │                     │          │
│         ▼                     ▼          │
│  ┌─────────────┐       ┌─────────────┐   │
│  │ PVC config  │       │  PVC data   │   │
│  └─────────────┘       └─────────────┘   │
└──────────────────────────────────────────┘
```

**BookStack** :
- Image : custom basée sur linuxserver/bookstack
- Port : 80 (HTTP)
- Volume : /config (uploads, cache)
- Probes : startup, readiness, liveness

**MariaDB** :
- Image : mariadb:11.4
- Port : 3306
- Volume : /var/lib/mysql

### 4.2 Dockerfile custom

```dockerfile
ARG BOOKSTACK_VERSION=25.12.2
FROM lscr.io/linuxserver/bookstack:version-v${BOOKSTACK_VERSION}

ARG BUILD_SHA=dev
LABEL org.opencontainers.image.revision=$BUILD_SHA

# Trace du build
RUN echo "${BUILD_SHA}" > /build_sha.txt

# CSS custom
COPY src/rncp.css /app/www/public/rncp.css

# Injection dans le layout
RUN set -e; \
  TARGET="$(grep -Rsl "</head>" /app/www/resources/views/layouts | head -n 1)"; \
  grep -q "rncp.css" "$TARGET" || \
  sed -i 's#</head>#<link rel="stylesheet" href="/rncp.css" />\n</head>#' "$TARGET"
```

L'image custom permet :
- De tracer le SHA du commit dans l'image
- D'injecter du CSS personnalisé
- De garder le contrôle sur la version de base

### 4.3 Kustomize overlays

Structure base/overlays pour gérer dev et prod :

```
k8s/
├── base/                    # Ressources communes
│   ├── kustomization.yaml
│   ├── bookstack-deployment.yaml
│   ├── bookstack-service.yaml
│   ├── bookstack-pvc.yaml
│   ├── bookstack-secrets.secret.sops.yaml
│   ├── mariadb-deployment.yaml
│   ├── mariadb-service.yaml
│   └── mariadb-pvc.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml   # namespace: bookstack-dev
    │   ├── ingress.yaml         # host: bookstackdev.rncp.idarius.net
    │   ├── bookstack-url.patch.yaml
    │   ├── networkpolicy.yaml
    │   └── resourcequota.yaml
    └── prod/
        └── (même structure, hosts différents)
```

Le `kustomization.yaml` de l'overlay :
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: bookstack-dev

resources:
- ../../base
- ingress.yaml
- networkpolicy.yaml
- resourcequota.yaml

patchesStrategicMerge:
- bookstack-url.patch.yaml

images:
- name: bookstack
  newName: idariusrncpacr.azurecr.io/bookstack
  newTag: sha-abc123
```

### 4.4 Pipeline CI/CD

#### Workflow CI (ci.yaml)

Déclenché sur push dans `app/**` sur la branche main.

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│Gitleaks │───►│  Build  │───►│  Trivy  │───►│  Push   │───►│ GitOps  │
│ (scan)  │    │ (local) │    │ (scan)  │    │  (ACR)  │    │(commit) │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

Étapes détaillées :

1. **Gitleaks** : scan du code pour détecter des secrets commités
2. **Build** : construction de l'image Docker en local (pas de push)
3. **Trivy** : scan de vulnérabilités sur l'image
   - Niveau : CRITICAL uniquement
   - Bloque le pipeline si trouvé
   - Génère un rapport SARIF pour l'onglet Security GitHub
4. **Push** : envoi vers ACR (seulement si scans OK)
5. **GitOps** : mise à jour du tag dans `k8s/overlays/dev/kustomization.yaml`

Le commit GitOps déclenche la synchronisation ArgoCD → déploiement automatique en dev.

#### Workflow Promote (promote-prod.yaml)

Déclenché manuellement pour promouvoir une image en production.

```
Input: image_tag (ex: sha-abc123)
  │
  ▼
┌───────────────────────────────────────┐
│ 1. Checkout branche main              │
│ 2. Valide format du tag               │
│ 3. Update overlays/prod/kustomization │
│ 4. Commit + push vers branche prod    │
└───────────────────────────────────────┘
  │
  ▼
ArgoCD sync branche prod → déploiement bookstack-prod
```

L'image n'est pas reconstruite : on réutilise exactement celle validée en dev.

#### Workflow Reset (reset-fallback.yaml)

Permet de revenir à l'image publique linuxserver/bookstack quand l'ACR est détruit (cycle destroy/apply de l'infra).

### 4.5 Flux de déploiement complet

```
Développeur                 GitHub                    Azure                    Cluster
    │                          │                        │                         │
    │ 1. Push app/             │                        │                         │
    ├─────────────────────────►│                        │                         │
    │                          │                        │                         │
    │                          │ 2. CI: build+scan      │                         │
    │                          ├───────────────────────►│                         │
    │                          │                        │                         │
    │                          │ 3. Push image ACR      │                         │
    │                          ├───────────────────────►│                         │
    │                          │                        │                         │
    │                          │ 4. Commit tag dev      │                         │
    │                          ├──────────┐             │                         │
    │                          │◄─────────┘             │                         │
    │                          │                        │                         │
    │                          │                        │  5. ArgoCD poll         │
    │                          │◄───────────────────────┼─────────────────────────┤
    │                          │                        │                         │
    │                          │                        │  6. Sync dev            │
    │                          │                        │─────────────────────────►
    │                          │                        │                         │
    │ 7. Test en dev           │                        │                         │
    │◄────────────────────────────────────────────────────────────────────────────┤
    │                          │                        │                         │
    │ 8. Workflow promote-prod │                        │                         │
    ├─────────────────────────►│                        │                         │
    │                          │                        │                         │
    │                          │ 9. Update tag prod     │                         │
    │                          ├──────────┐             │                         │
    │                          │◄─────────┘             │                         │
    │                          │                        │                         │
    │                          │                        │  10. ArgoCD poll        │
    │                          │◄───────────────────────┼─────────────────────────┤
    │                          │                        │                         │
    │                          │                        │  11. Sync prod          │
    │                          │                        │─────────────────────────►
    │                          │                        │                         │
```

### 4.6 Sécurité applicative

**NetworkPolicy**

Isole les namespaces entre eux :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-from-other-namespaces
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}           # Même namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik  # Ingress controller
```

**ResourceQuota**

Limite les ressources par namespace :
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "1Gi"
    limits.cpu: "1"
    limits.memory: "2Gi"
    persistentvolumeclaims: "4"
    pods: "10"
```

---

## 5. Décisions techniques

### 5.1 Pourquoi ces choix ?

| Choix | Alternatives considérées | Justification |
|-------|-------------------------|---------------|
| **AKS** | EKS, GKE, K3s | Intégration native Azure, Managed Identity, moins de configuration réseau |
| **ArgoCD** | FluxCD, Jenkins X | Interface web, adoption large, bonne intégration Helm/Kustomize |
| **Traefik** | Nginx Ingress, HAProxy | Plus léger, configuration via annotations, CRDs disponibles |
| **SOPS/Age** | Sealed Secrets, Vault | Simple, pas de composant serveur, fonctionne hors cluster |
| **Kustomize** | Helm pour l'app | Meilleur pour les overlays env, pas besoin de templating complexe |
| **GitHub Actions** | GitLab CI, Jenkins | Intégré à GitHub, OIDC natif avec Azure |
| **Velero** | Kasten, Stash | Open source, supporte Azure nativement, actif |

### 5.2 Compromis assumés

**Cluster mono-noeud**
- Raison : budget et simplification pour la démo
- Impact : pas de HA, pas de PodDisruptionBudget utile
- En production : minimum 3 noeuds sur plusieurs zones

**API Kubernetes publique**
- Raison : simplicité d'accès pour la démo
- Mitigation : whitelist IP configurable
- En production : API privée + bastion ou VPN

**Deployment pour MariaDB (pas StatefulSet)**
- Raison : simplification, un seul replica
- Impact : pas d'identité stable du pod
- En production : StatefulSet ou service managé (Azure Database)

**Secrets partagés dev/prod**
- Raison : simplification pour la démo
- Impact : même credentials sur les deux environnements
- En production : secrets séparés par environnement

**Pas de backend remote Terraform**
- Raison : projet individuel, pas de collaboration
- Impact : state local, pas de locking
- En production : Azure Blob + state locking

### 5.3 Améliorations possibles

Pour un environnement de production réel :

1. **Haute disponibilité**
   - Multi-noeud, multi-zone
   - PodDisruptionBudget
   - Horizontal Pod Autoscaler

2. **Sécurité renforcée**
   - API privée + Private Link
   - Azure Policy / Gatekeeper
   - Pod Security Standards
   - Scan d'images en continu

3. **Observabilité avancée**
   - Logs centralisés (Loki, Azure Monitor)
   - Tracing distribué (Jaeger, Tempo)
   - Alertes PagerDuty/Slack

4. **Données**
   - Base de données managée
   - Backups cross-region
   - Encryption at rest

5. **CI/CD**
   - Environnement de staging
   - Tests d'intégration automatisés
   - Canary deployments

---

## Annexes

### A. Commandes utiles

```bash
# Déploiement complet
make demo-up

# Accès aux interfaces
make forward-argocd    # https://localhost:8080
make forward-grafana   # http://localhost:3000
make pass-argocd       # Mot de passe admin ArgoCD
make pass-grafana      # Mot de passe admin Grafana

# Backups
make velero-backup-dev
make velero-restore-dev BACKUP=<backup-name>

# Destruction
make tf-destroy
```

### B. URLs

| Service | URL |
|---------|-----|
| BookStack Dev | https://bookstackdev.rncp.idarius.net |
| BookStack Prod | https://bookstackprod.rncp.idarius.net |
| ArgoCD | localhost:8080 (port-forward) |
| Grafana | localhost:3000 (port-forward) |
| Prometheus | localhost:9090 (port-forward) |

### C. Repositories

- Infrastructure : https://github.com/idarius/devops-iac-azure
- Plateforme : https://github.com/idarius/devops-platform-k8s
- Application : https://github.com/idarius/devops-app-bookstack
