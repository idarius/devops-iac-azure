resource "helm_release" "argocd_apps" {
  depends_on = [helm_release.argocd]

  name      = "argocd-apps"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.4"

  timeout         = 900
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [<<-YAML
applications:
  platform-root:
    namespace: argocd
    project: default
    source:
      repoURL: https://github.com/idarius/devops-platform-k8s.git
      targetRevision: main
      path: cluster/rncp-aks
      directory:
        recurse: true
        include: '{**/*project.yaml,**/application.yaml,**/applicationset.yaml}'
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
