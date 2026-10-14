# ---------------------------------------------------------------------------
# main.tf - composicion de modulos del ambiente prod
# ---------------------------------------------------------------------------
# Este fichero no crea recursos "a mano": llama a los modulos de
# infra/modules y los conecta entre si.

# "data": LEE informacion de algo que ya existe, sin crearlo. Aqui, quien eres
# tu segun la sesion de az login (tenant, etc.).
data "azurerm_client_config" "current" {}

# "random_string": genera un texto aleatorio que Terraform GUARDA en el state,
# asi no cambia en cada ejecucion. Sirve de sufijo para nombres globales unicos.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# "locals": valores calculados reutilizables dentro de este directorio.
locals {
  # Prefijo comun de nombres: devopslab-prod
  name_prefix = "${var.project}-${var.environment}"

  # Sufijo para nombres globalmente unicos.
  suffix = random_string.suffix.result

  # El ACR no admite guiones: quitamos los del prefijo y anadimos el sufijo.
  acr_name = "${replace(local.name_prefix, "-", "")}${local.suffix}"

  # Etiquetas comunes para todos los recursos.
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "resource_group" {
  source = "../../modules/resource_group"

  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  name = local.acr_name

  # Dependencia implicita: usa salidas de module.resource_group.
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = var.acr_sku
  tags                = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  log_analytics_name        = "log-${local.name_prefix}"
  application_insights_name = "appi-${local.name_prefix}"
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  retention_in_days         = var.log_retention_days
  tags                      = local.tags
}

module "app_service" {
  source = "../../modules/app_service"

  plan_name           = "asp-${local.name_prefix}"
  app_name            = "app-${local.name_prefix}-${local.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku_name            = var.app_service_sku
  always_on           = var.always_on
  docker_image_name   = var.docker_image_name

  # Salidas de los modulos acr y monitoring: Terraform crea esos antes.
  acr_id                                 = module.acr.id
  acr_login_server                       = module.acr.login_server
  application_insights_connection_string = module.monitoring.connection_string

  tags = local.tags

  # depends_on = [module.acr] seria redundante: ya depende de el por las
  # referencias de arriba. Se usa solo para dependencias que no se ven.
}
