############################
# Outputs
############################

output "resource_group_name" {
  description = "Nom du Resource Group créé par Terraform"
  value       = azurerm_resource_group.rg.name
}

output "aks_name" {
  description = "Nom du cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
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
  description = "Storage Account pour les backups Velero"
  value       = azurerm_storage_account.sa.name
}

output "velero_container_name" {
  description = "Container Blob pour Velero"
  value       = azurerm_storage_container.velero.name
}
