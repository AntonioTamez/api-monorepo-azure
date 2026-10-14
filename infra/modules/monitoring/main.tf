# ---------------------------------------------------------------------------
# Modulo monitoring
# ---------------------------------------------------------------------------
# Log Analytics workspace: almacen central de logs y metricas.
# Application Insights: monitoriza la aplicacion (peticiones, errores) y
# guarda sus datos dentro del workspace.

resource "azurerm_log_analytics_workspace" "this" {
  name = var.log_analytics_name

  resource_group_name = var.resource_group_name

  location = var.location

  # "PerGB2018" es el modelo de precio vigente: pagas por GB ingerido.
  sku = "PerGB2018"

  # Dias que se conservan los datos. Mas dias = mas costo.
  retention_in_days = var.retention_in_days

  tags = var.tags
}

resource "azurerm_application_insights" "this" {
  name = var.application_insights_name

  resource_group_name = var.resource_group_name

  location = var.location

  # Dependencia implicita: usamos un atributo del workspace de arriba, asi que
  # Terraform lo crea primero. Apunta Application Insights a ese workspace
  # (modo "workspace-based", el recomendado hoy).
  workspace_id = azurerm_log_analytics_workspace.this.id

  # Tipo de aplicacion que se monitoriza: "web" para una API o web.
  application_type = "web"

  tags = var.tags
}
