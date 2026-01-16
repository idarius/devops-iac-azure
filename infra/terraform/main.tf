############################
# 0) Suffixe aléatoire
############################
# Objectif : éviter les collisions de noms (ACR/Storage doivent être uniques globalement)
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  # Suffixe court commun
  name_suffix = random_string.suffix.result

  # Tout est contenu dans un seul resource group :
  rg_name  = "${var.prefix}-rg-${local.name_suffix}"
  aks_name = "${var.prefix}-aks-${local.name_suffix}"

  # ACR/Storage : contraintes de nommage (minuscule, sans tirets, longueur, etc.)
  # On utilise var.prefix_compact + suffixe.
  acr_name = "${var.prefix_compact}acr${local.name_suffix}"
  sa_name  = "${var.prefix_compact}sa${local.name_suffix}"

  # Container Blob dédié à Velero
  velero_container_name = "velero"
}

############################
# 1) Resource Group
############################
# Tout est mis dans ce RG (AKS/ACR/Storage…)
# Avantage : un destroy beaucoup plus fiable.
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

############################
# 2) Azure Container Registry (ACR)
############################
# On utilise SKU Basic : suffisant pour pousser des images Docker pour ce projet.
# admin_enabled = false : on évite le mode "admin".
resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku           = "Basic"
  admin_enabled = false

  tags = var.tags
}

############################
# 3) Storage Account + container Blob pour Velero
############################
# Objectif : stocker les sauvegardes Velero (manifests + volumes)
resource "azurerm_storage_account" "sa" {
  name                = local.sa_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Standard + LRS pour minimiser les coûts
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Sécurité de base : pas de contenu public
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "velero" {
  name                  = local.velero_container_name
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

############################
# 4) AKS - cluster Kubernetes
############################
# - API server public (administration simplifiée)
# - 1 node B2s (suffisant pour ce projet)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # dns_prefix (sert au FQDN du control plane)
  dns_prefix = "${var.prefix}-dns-${local.name_suffix}"

  # Azure gère l'identité du cluster
  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size

    # Disque OS raisonnable pour le node
    os_disk_size_gb = 30
  }

  # Réseau :
  # Azure CNI (standard AKS)
  network_profile {
    network_plugin = "azure"
  }

  tags = var.tags
}

############################
# 5) Autoriser AKS à pull sur ACR
############################
# On assigne le rôle AcrPull à l'identité kubelet du cluster, pour pouvoir pull depuis ACR.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
