variable "location" {
  type        = string
  description = "Region Azure"
  default     = "westeurope"
}

variable "prefix" {
  type        = string
  description = "Préfixe lisible (noms RG/AKS)"
  default     = "idarius-rncp"
}

variable "prefix_compact" {
  type        = string
  description = "Préfixe compact (sans tirets) pour respecter les contraintes ACR/Storage"
  default     = "idariusrncp"

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.prefix_compact))
    error_message = "prefix_compact doit contenir uniquement des lettres minuscules et des chiffres (pas de tirets)."
  }
}

variable "aks_node_size" {
  type        = string
  description = "Taille des nodes AKS"
  default     = "Standard_B2s_v2"
}

variable "aks_max_pods" {
  type        = number
  description = "Nombre de pods max par node AKS"
  default     = 60

  validation {
    condition     = var.aks_max_pods >= 10 && var.aks_max_pods <= 250
    error_message = "aks_max_pods doit être entre 10 et 250."
  }
}

variable "aks_node_count" {
  type        = number
  description = "Nombre de nodes AKS"
  default     = 1
}

variable "tags" {
  type        = map(string)
  description = "Tags communs"
  default = {
    project = "rncp-devops"
    owner   = "idarius"
  }
}

variable "aks_api_authorized_ip_ranges" {
  type        = list(string)
  description = "Liste d'IPs/CIDR autorisés à accéder à l'API AKS. laisser vide pour ne pas restreindre, ou passer en variable export TF_VAR_aks_api_authorized_ip_ranges='[]' "
  default     = []
}



########################################
# GitHub (OIDC + variables GitHub Actions)
########################################

variable "github_owner" {
  type        = string
  description = "Propriétaire du repo Github"
  default     = "idarius"
}

variable "github_repo_bookstack" {
  type        = string
  description = "Repo GitHub de l'app (bookstack)"
  default     = "devops-app-bookstack"
}

variable "github_branch" {
  type        = string
  description = "Branche autorisée pour le login OIDC GitHub Actions"
  default     = "main"
}

variable "github_token" {
  type        = string
  description = "GitHub token (PAT) pour que Terraform crée automatiquement les GitHub Actions Variables"
  sensitive   = true
}

##########
# Velero
##########
variable "velero_enable_rg_contributor" {
  type        = bool
  description = "Autorise Velero en Contributor sur le RG (si besoin de snapshots Azure)"
  default     = false
}

########
# KSOPS 
########
variable "ksops_version" {
  type        = string
  description = "Version de KSOPS installée dans ArgoCD"
  default     = "4.4.0"
}

variable "ksops_sha256" {
  type        = string
  description = "SHA256 du binaire KSOPS pour vérification d'intégrité"
  default     = "72973ce5a97d7ad0318c9f6ae4df2aa94a4a564c45fdf71772b759dff4df0cb4"
}