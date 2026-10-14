# ---------------------------------------------------------------------------
# backend.tf - donde se guarda el state (ambiente prod)
# ---------------------------------------------------------------------------
# Un "backend" define donde vive el state. "azurerm" = un blob de Azure Storage
# (creado con infra/bootstrap), con locking automatico.
#
# CONFIGURACION PARCIAL: el bloque backend NO admite variables, y los nombres de
# la cuenta de Storage dependen de cada persona. Por eso aqui solo ponemos lo
# fijo y el resto se pasa al inicializar:
#
#   terraform init `
#     -backend-config="resource_group_name=rg-devopslab-tfstate" `
#     -backend-config="storage_account_name=<cuenta impresa por el script>" `
#     -backend-config="container_name=tfstate"
terraform {
  backend "azurerm" {
    # Nombre del blob dentro del contenedor. Un fichero por ambiente.
    key = "prod.tfstate"

    # Autenticarse con tu identidad de Entra ID (az login) en vez de con claves
    # de la cuenta. Requiere el rol "Storage Blob Data Contributor".
    use_azuread_auth = true
  }
}
