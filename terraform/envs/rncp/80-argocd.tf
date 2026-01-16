resource "helm_release" "argocd" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.3.4"

  timeout         = 900
  wait            = true
  atomic          = true
  cleanup_on_fail = true

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
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi

extraObjects:
  - apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: platform-root
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/idarius/devops-platform-k8s.git
        targetRevision: main
        path: clusters/rncp-aks
        directory:
          recurse: true
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
YAML
  ]
}
