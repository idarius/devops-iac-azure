################################################
# Storage Account + container Blob pour Velero #
################################################

resource "azurerm_storage_account" "sa" {
  name                = local.sa_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false

  # sécurité
  min_tls_version             = "TLS1_2"
  https_traffic_only_enabled  = true

  tags = var.tags
}

resource "azurerm_storage_container" "velero" {
  name                  = local.velero_container_name
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}
