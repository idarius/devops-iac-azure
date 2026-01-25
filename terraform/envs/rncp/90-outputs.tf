output "resource_group_name" {
  description = "Nom du Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "aks_name" {
  description = "Nom du cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_fqdn" {
  description = "FQDN de l'API server AKS"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "acr_name" {
  description = "Nom du registry ACR"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "URL du registry ACR"
  value       = azurerm_container_registry.acr.login_server
}

output "storage_account_name" {
  description = "Storage Account (Velero)"
  value       = azurerm_storage_account.sa.name
}

output "velero_container_name" {
  description = "Container Blob Velero"
  value       = azurerm_storage_container.velero.name
}

output "gha_acr_client_id" {
  description = "Client ID (App Registration) pour OIDC GitHub Actions -> Azure"
  value       = azuread_application.gha_acr.client_id
}

output "tenant_id" {
  description = "Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "storage_account_key" {
  description = "Primary access key du Storage Account (Velero) - à mettre dans le secret cloud-credentials"
  value       = azurerm_storage_account.sa.primary_access_key
  sensitive   = true
}

output "velero_client_id" {
  description = "Client ID (App Registration) pour Velero"
  value       = azuread_application.velero.client_id
}

output "velero_client_secret" {
  description = "Client Secret pour Velero"
  value       = azuread_service_principal_password.velero.value
  sensitive   = true
}