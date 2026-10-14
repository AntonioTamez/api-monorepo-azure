# versions.tf - requisitos de versiones del modulo.
# Ver infra/modules/resource_group/versions.tf para la explicacion detallada.
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
