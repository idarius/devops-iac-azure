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

