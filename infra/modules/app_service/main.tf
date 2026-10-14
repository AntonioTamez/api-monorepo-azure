# ---------------------------------------------------------------------------
# Modulo app_service
# ---------------------------------------------------------------------------
# Un App Service se compone de dos piezas:
#  1. App Service Plan: la "maquina" (tamano y precio) donde corre la app.
#  2. Web App: tu aplicacion, que corre dentro del plan.
# Ademas damos permiso a la app para descargar imagenes del ACR.

resource "azurerm_service_plan" "this" {
  name = var.plan_name

  resource_group_name = var.resource_group_name

  location = var.location

  # "Linux" porque nuestro contenedor es Linux.
  os_type = "Linux"

  # SKU = tamano/precio. B1 (Basic) para dev; P1v3 (Premium) para prod.
  # Ver docs/09 para la tabla de costos.
  sku_name = var.sku_name

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name = var.app_name

  resource_group_name = var.resource_group_name

  location = var.location

  # Dependencia implicita: referenciamos el id del plan, asi que el plan se
  # crea ANTES que la web app. No hace falta depends_on.
  service_plan_id = azurerm_service_plan.this.id

  # Solo HTTPS: las peticiones HTTP se redirigen.
  https_only = true

  # Identidad administrada: Azure crea un "service principal" para esta app y
  # gestiona sus credenciales. Es lo que usara para autenticarse en el ACR sin
  # contrasenas. SystemAssigned = nace y muere con la app.
  identity {
    type = "SystemAssigned"
  }

  # Configuracion variable de la app, expuesta como variables de entorno.
  app_settings = {
    # Puerto que escucha el contenedor (el Dockerfile usa 8080).
    WEBSITES_PORT = "8080"

    # Evita montar almacenamiento persistente compartido: no lo necesitamos.
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"

    # Conecta la app con Application Insights.
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
  }

  site_config {
    # always_on mantiene la app cargada. No esta disponible en niveles Free.
    always_on = var.always_on

    # Azure llama a esta ruta; si no responde 200, marca la instancia no sana.
    health_check_path = "/health"

    # Usa la identidad administrada (no usuario/contrasena) para descargar la
    # imagen del registro.
    container_registry_use_managed_identity = true

    application_stack {
      # Registro de donde se descarga, con https://
      docker_registry_url = "https://${var.acr_login_server}"

      # Imagen con tag: "api:latest" o "api:<sha>". El pipeline CD la cambiara.
      docker_image_name = var.docker_image_name
    }
  }

  # lifecycle controla como Terraform trata el recurso a lo largo del tiempo.
  # ignore_changes: si el pipeline de CD despliega otra imagen (otro tag),
  # Terraform NO debe "corregirla" de vuelta a la que pone aqui.
  lifecycle {
    ignore_changes = [site_config[0].application_stack[0].docker_image_name]
  }

  tags = var.tags
}

# Role assignment (asignacion de rol): identidad + rol + ambito.
# Aqui: la identidad de la web app puede LEER (descargar) imagenes del ACR.
resource "azurerm_role_assignment" "acr_pull" {
  # Ambito: solo este registro, no toda la suscripcion (minimo privilegio).
  scope = var.acr_id

  # Rol integrado de Azure que permite descargar imagenes, nada mas.
  role_definition_name = "AcrPull"

  # Dependencia implicita: el principal_id solo existe cuando la web app ya fue
  # creada, asi que Terraform espera a que termine. Por eso tampoco hace falta
  # depends_on (usalo solo cuando la dependencia NO se ve en los atributos).
  principal_id = azurerm_linux_web_app.this.identity[0].principal_id
}
