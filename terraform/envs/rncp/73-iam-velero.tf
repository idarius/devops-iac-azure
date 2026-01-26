##########################################
# Velero - identité Azure + permissions   #
##########################################

# Application Azure AD pour Velero
resource "azuread_application" "velero" {
  display_name = "${var.prefix}-velero-${local.name_suffix}"
}

# Client/service principal pour Velero
resource "azuread_service_principal" "velero" {
  client_id = azuread_application.velero.client_id
}

# Secret pour l'authentification
resource "azuread_service_principal_password" "velero" {
  service_principal_id = azuread_service_principal.velero.id
  display_name         = "velero-client-secret"

  end_date_relative = "17520h" # 2 ans
}

# Blob access (object storage)
resource "azurerm_role_assignment" "velero_blob_data_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.velero.object_id

  skip_service_principal_aad_check = true
}

# OPTIONAL: si besoin d'activer les snapshots Azure
resource "azurerm_role_assignment" "velero_rg_contributor" {
  count = var.velero_enable_rg_contributor ? 1 : 0

  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.velero.object_id

  skip_service_principal_aad_check = true
}
