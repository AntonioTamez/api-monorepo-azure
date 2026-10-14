# ---------------------------------------------------------------------------
# providers.tf - versiones y configuracion de providers (ambiente dev)
# ---------------------------------------------------------------------------

# El bloque "terraform" configura la herramienta en si.
terraform {
  # Version minima del binario terraform.
  required_version = ">= 1.9.0"

  # Providers (plugins) que se descargaran en "terraform init".
  required_providers {
    # Provider de Azure.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Provider "random": genera valores aleatorios (usamos un sufijo para que
    # los nombres globales de ACR y Web App sean unicos).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Configuracion del provider azurerm. A diferencia de los modulos, aqui SI se
# configura (una sola vez por directorio raiz).
provider "azurerm" {
  # Obligatorio en azurerm 4.x (el bloque features puede ir vacio).
  features {}

  # En que suscripcion de Azure se crean los recursos. No es secreto, pero es
  # especifico de cada persona, por eso se pasa por variable de entorno:
  #   $env:TF_VAR_subscription_id = "<SUBSCRIPTION_ID>"
  subscription_id = var.subscription_id
}
