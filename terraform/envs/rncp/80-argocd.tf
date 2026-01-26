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

global:
  image:
    repository: quay.io/argoproj/argocd
    tag: v3.2.5
    
server:
  service:
    type: ClusterIP

# Active KSOPS via kustomize alpha plugins + exec
configs:
  cm:
    kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"

repoServer:
  replicas: 1

  volumes:
    - name: custom-tools
      emptyDir: {}
    - name: kustomize-plugins
      emptyDir: {}
    - name: sops-age
      secret:
        secretName: sops-age
        optional: true

  initContainers:
    # 1) Copie kustomize depuis l'image Argo CD (déjà OK et pullable)
    - name: copy-kustomize
      image: quay.io/argoproj/argocd:v3.2.5
      command: ["/bin/cp"]
      args: ["-f", "/usr/local/bin/kustomize", "/custom-tools/kustomize"]
      volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools

    # 2) Télécharge ksops depuis GitHub Releases + l'installe comme plugin Kustomize
    - name: install-ksops
      image: alpine:3.20
      command: ["/bin/sh", "-c"]
      args:
      args:
        - |
          set -euo pipefail
          apk add --no-cache curl tar

          KSOPS_VERSION="${var.ksops_version}"
          ASSET="ksops_${KSOPS_VERSION}_Linux_x86_64.tar.gz"
          URL="https://github.com/viaduct-ai/kustomize-sops/releases/download/v${KSOPS_VERSION}/${ASSET}"

          # SHA256 "pinné" via Terraform (référence fixe dans ton repo)
          EXPECTED_SHA="${var.ksops_sha256}"

          # Download
          curl -fsSL -o "/tmp/${ASSET}" "${URL}"

          # Vérif SHA256 : si mismatch => fail (et donc repo-server ne démarre pas avec un binaire altéré)
          echo "${EXPECTED_SHA}  /tmp/${ASSET}" | sha256sum -c -

          # Install binaire
          tar -xzf "/tmp/${ASSET}" -C /tmp
          mv /tmp/ksops /custom-tools/ksops
          chmod +x /custom-tools/ksops

          # Install plugin au chemin attendu par Kustomize exec plugins
          mkdir -p /kustomize-plugins/viaduct.ai/v1/ksops
          cp /custom-tools/ksops /kustomize-plugins/viaduct.ai/v1/ksops/ksops
          chmod +x /kustomize-plugins/viaduct.ai/v1/ksops/ksops

      volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools
        - name: kustomize-plugins
          mountPath: /kustomize-plugins

  volumeMounts:
    # kustomize binaire
    - name: custom-tools
      mountPath: /usr/local/bin/kustomize
      subPath: kustomize

    # (optionnel) garder ksops aussi dans PATH pour debug
    - name: custom-tools
      mountPath: /usr/local/bin/ksops
      subPath: ksops

    # plugin path Kustomize
    - name: kustomize-plugins
      mountPath: /.config/kustomize/plugin

    # clé Age SOPS
    - name: sops-age
      mountPath: /.config/sops/age

  env:
    - name: XDG_CONFIG_HOME
      value: /.config
    - name: HOME
      value: /.config
    - name: KUSTOMIZE_PLUGIN_HOME
      value: /.config/kustomize/plugin
    - name: SOPS_AGE_KEY_FILE
      value: /.config/sops/age/age.agekey


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
YAML
  ]
}
