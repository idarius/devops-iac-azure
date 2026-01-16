variable "location" {
  type        = string
  description = "Region Azure"
  default     = "westeurope"
}

variable "prefix" {
  type        = string
  description = "Préfixe lisible"
  default     = "idarius-rncp"
}

variable "prefix_compact" {
  type        = string
  description = "Préfixe sans - pour respecter les contraintes de nommage"
  default     = "idariusrncp"
}

variable "aks_node_size" {
  type        = string
  description = "Taille des nodes AKS"
  default     = "Standard_B2s_v2"
}

variable "aks_max_pods" {
  type        = string
  description = "Nombre de pods max par nodes AKS"
  default     = 60
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

variable "subscription_id" {
  type        = string
  description = "Subscription Azure cible"
}