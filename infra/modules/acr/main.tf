# ---------------------------------------------------------------------------
# Modulo acr
# ---------------------------------------------------------------------------
# ACR (Azure Container Registry) es el almacen privado donde se guardan las
# imagenes Docker de la API. El App Service las descargara de aqui.

resource "azurerm_container_registry" "this" {
  # Nombre GLOBALMENTE unico en todo Azure: 5-50 caracteres, solo letras y
  # numeros (sin guiones). Forma parte de la URL: <name>.azurecr.io
  name = var.name

  # Dependencia implicita: el valor llega por variable desde el ambiente, que
  # lo toma de la salida del modulo resource_group. Asi Terraform sabe que el
  # grupo debe existir antes que el registro.
  resource_group_name = var.resource_group_name

  location = var.location

  # Nivel de servicio y precio: Basic (barato, para dev), Standard o Premium.
  sku = var.sku

  # admin_enabled = false desactiva el usuario/contrasena compartido del
  # registro. Nadie tiene una contrasena que pueda filtrarse: el App Service
  # usara su identidad administrada con el rol AcrPull.
  admin_enabled = false

  tags = var.tags
}
