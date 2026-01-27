# ArgoCD avec KSOPS pour déchiffrer les secrets SOPS
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

# Activation de KSOPS via kustomize alpha plugins
configs:
  cm:
    kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"

repoServer:
  replicas: 1

  # Volumes pour kustomize, ksops et la clé Age
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
    # Copie du binaire kustomize depuis l'image ArgoCD
    - name: copy-kustomize
      image: quay.io/argoproj/argocd:v3.2.5
      command: ["/bin/cp"]
      args: ["-f", "/usr/local/bin/kustomize", "/custom-tools/kustomize"]
      volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools

    # Installation de ksops avec vérification SHA256
    - name: install-ksops
      image: alpine:3.20
      command: ["/bin/sh", "-c"]
      args:
        - |
          set -euo pipefail
          apk add --no-cache curl tar coreutils

          KSOPS_VERSION="${var.ksops_version}"
          ASSET="ksops_$${KSOPS_VERSION}_Linux_x86_64.tar.gz"
          URL="https://github.com/viaduct-ai/kustomize-sops/releases/download/v$${KSOPS_VERSION}/$${ASSET}"
          EXPECTED_SHA="${var.ksops_sha256}"

          # Download et vérification SHA256
          curl -fsSL -o "/tmp/$${ASSET}" "$${URL}"
          echo "$${EXPECTED_SHA}  /tmp/$${ASSET}" | sha256sum -c -

          # Extraction et installation du binaire
          tar -xzf "/tmp/$${ASSET}" -C /tmp
          mv /tmp/ksops /custom-tools/ksops
          chmod +x /custom-tools/ksops

          # Installation du plugin kustomize
          mkdir -p /kustomize-plugins/viaduct.ai/v1/ksops
          cp /custom-tools/ksops /kustomize-plugins/viaduct.ai/v1/ksops/ksops
          chmod +x /kustomize-plugins/viaduct.ai/v1/ksops/ksops

      volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools
        - name: kustomize-plugins
          mountPath: /kustomize-plugins

  volumeMounts:
    - name: custom-tools
      mountPath: /usr/local/bin/kustomize
      subPath: kustomize

    - name: custom-tools
      mountPath: /usr/local/bin/ksops
      subPath: ksops

    - name: kustomize-plugins
      mountPath: /.config/kustomize/plugin

    - name: sops-age
      mountPath: /.config/sops/age

  # Config pour KSOPS et SOPS
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

# Notifications et ressources par composant
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
