###############################################
# GitHub Actions Variables (repo devops-app-*) #
###############################################

resource "github_actions_variable" "acr_name" {
  repository    = var.github_repo_bookstack
  variable_name = "ACR_NAME"
  value         = azurerm_container_registry.acr.name
}

resource "github_actions_variable" "acr_login_server" {
  repository    = var.github_repo_bookstack
  variable_name = "ACR_LOGIN_SERVER"
  value         = azurerm_container_registry.acr.login_server
}

resource "github_actions_variable" "azure_client_id" {
  repository    = var.github_repo_bookstack
  variable_name = "AZURE_CLIENT_ID"
  value         = azuread_application.gha_acr.client_id
}

resource "github_actions_variable" "azure_tenant_id" {
  repository    = var.github_repo_bookstack
  variable_name = "AZURE_TENANT_ID"
  value         = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_variable" "azure_subscription_id" {
  repository    = var.github_repo_bookstack
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = data.azurerm_subscription.current.subscription_id
}
