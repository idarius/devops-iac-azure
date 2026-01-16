provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# On s'authentifie via Azure CLI :
# az login
