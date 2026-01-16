############################
# AKS - cluster Kubernetes #
############################

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dns_prefix = "${var.prefix}-dns-${local.name_suffix}"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size
    max_pods = var.aks_max_pods

    os_disk_size_gb = 30
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = var.tags
}
