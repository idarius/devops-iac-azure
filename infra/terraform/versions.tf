terraform {
  # Version Terraform minimale pour la coherence du projet
  required_version = ">= 1.6.0"

  required_providers {
    # Provider Azure officiel HashiCorp
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Pour générer un suffixe aléatoire dans les noms
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # Provider Kubernetes (pilotage du cluster depuis Terraform)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    # Provider Helm (installation de charts, pour Argo CD)
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
}