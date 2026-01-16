############################################
# Bootstrap Argo CD
# - Création namespace
# - Installation via Helm chart officiel
############################################

# Namespace argocd
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
}

# Installation Argo CD via Helm
resource "helm_release" "argocd" {
  depends_on = [azurerm_kubernetes_cluster.aks]
  name      = "argocd"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  # Version pour la reproductibilité
  version = "7.6.12"

  # Sécurité / stabilité
  timeout         = 900
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  # Pour démarrer simple : service en ClusterIP (accès par port-forward)
  values = [<<-YAML
server:
  service:
    type: ClusterIP

repoServer:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 300m
      memory: 256Mi

applicationSet:
  replicaCount: 1

notifications:
  enabled: true
  resources:
    requests:
      cpu: 10m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

controller:
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
YAML
]
}
