##############################
# Suffixe aléatoire + locals #
##############################

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  name_suffix = random_string.suffix.result

  # Tout est contenu dans un seul resource group :
  rg_name  = "${var.prefix}-rg-${local.name_suffix}"
  aks_name = "${var.prefix}-aks-${local.name_suffix}"

  # ACR/Storage : contraintes de nommage (minuscule, sans tirets, longueur, etc.)
  acr_name = "${var.prefix_compact}acr${local.name_suffix}"
  sa_name  = "${var.prefix_compact}sa${local.name_suffix}"

  # Container Blob dédié à Velero
  velero_container_name = "velero"
}
