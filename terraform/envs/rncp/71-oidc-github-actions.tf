###############################################
# OIDC GitHub Actions -> Azure (push vers ACR) #
###############################################

locals {
  github_repo_full_name = "${var.github_owner}/${var.github_repo_bookstack}"
}

resource "azuread_application" "gha_acr" {
  display_name = "${var.prefix}-gha-acr-${local.name_suffix}"
}

resource "azuread_service_principal" "gha_acr" {
  client_id = azuread_application.gha_acr.client_id
}

# Autorise GitHub Actions (branche main) à obtenir un token Azure via OIDC
resource "azuread_application_federated_identity_credential" "gha_main" {
  application_id = azuread_application.gha_acr.id
  display_name   = "github-actions-main"
  description    = "OIDC GitHub Actions pour ${local.github_repo_full_name} (branch ${var.github_branch})"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${local.github_repo_full_name}:ref:refs/heads/${var.github_branch}"
}

# Donne le droit de push dans ACR
resource "azurerm_role_assignment" "gha_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.gha_acr.object_id

  skip_service_principal_aad_check = true
}
