# devops-iac-azure

Infrastructure Azure (IaC) pour le projet RNCP DevOps.

## Ce que ce Terraform crée
- 1 Resource Group (RG) dédié au projet
- 1 AKS (API publique) avec 1 node (Standard_B2s_v2)
- 1 Azure Container Registry (SKU Basic)
- 1 Storage Account + 1 container Blob (pour les sauvegardes Velero)

## Objectif
- Avoir une infra **reproductible** (`terraform apply`)
- Et surtout **facile à détruire** (`terraform destroy`) afin de maîtriser les coûts.

## Pré-requis
- Terraform
- Azure CLI (`az`)
- Auth Azure : `az login` (ou `az login --use-device-code`)

## Exécution
```bash
cd infra/terraform
terraform init
terraform plan -out tfplan
terraform apply tfplan