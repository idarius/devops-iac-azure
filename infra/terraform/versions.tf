terraform {
  # Version Terraform minimale pour éviter les surprises
  required_version = ">= 1.6.0"

  required_providers {
    # Provider Azure officiel HashiCorp
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Pour générer un suffixe aléatoire dans les noms (évite collisions)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}