# 08 - Terraform: módulos

Requisito: haber leído [07 - Fundamentos](07-terraform-fundamentos.md).

## 1. Por qué módulos

Dev y prod necesitan la **misma** infraestructura con valores distintos (tamaños, nombres). Si copiaras los recursos en ambos sitios, cada arreglo habría que hacerlo dos veces. Un **módulo** es una carpeta con recursos relacionados que se usa como una función: recibe **inputs** (variables), crea recursos y devuelve **outputs**.

```hcl
module "acr" {
  source = "../../modules/acr"   # ruta a la carpeta del módulo

  name                = "devopslabdevab12"   # inputs
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "Basic"
}

# Después: module.acr.login_server   <- output del módulo
```

Dentro de cada módulo:

| Fichero | Contenido |
| --- | --- |
| `main.tf` | Los recursos. |
| `variables.tf` | Inputs. |
| `outputs.tf` | Outputs. |
| `versions.tf` | Versión de Terraform y de providers que necesita. **No** configura el provider: eso lo hace el ambiente. |

Los módulos de este repo son locales (`infra/modules/*`). También existen módulos publicados en el Terraform Registry, pero para aprender es mejor escribir los propios.

## 2. Mapa de módulos

```
resource_group ──► acr ───────────────┐
        │                              ▼
        ├──► monitoring ───────► app_service ──(rol AcrPull)──► acr
```

Un ambiente (`infra/envs/dev`) los compone y conecta sus outputs con los inputs del siguiente. Terraform deduce el orden de creación de esas conexiones.

## 3. Convención de nombres

Patrón: `<tipo>-<proyecto>-<ambiente>`, por ejemplo `rg-devopslab-dev`.

| Recurso | Prefijo | Ejemplo | Restricción |
| --- | --- | --- | --- |
| Resource group | `rg-` | `rg-devopslab-dev` | Único en la suscripción |
| Container Registry | *(sin prefijo ni guiones)* | `devopslabdevab12` | **Único en todo Azure**, 5-50 caracteres, solo letras minúsculas y números |
| App Service Plan | `asp-` | `asp-devopslab-dev` | Único en el grupo |
| Web App | `app-` | `app-devopslab-dev-ab12` | **Único en todo Azure** (forma `app-....azurewebsites.net`) |
| Log Analytics | `log-` | `log-devopslab-dev` | Único en el grupo |
| Application Insights | `appi-` | `appi-devopslab-dev` | Único en el grupo |

Para los nombres globales se añade un **sufijo aleatorio** (4 caracteres) generado por Terraform con el recurso `random_string`; así dos alumnos con el mismo `project` no chocan.

## 4. Tags

Cada recurso recibe `tags = var.tags`. El ambiente define un único mapa en `locals` (`project`, `environment`, `managed_by = "terraform"`) y lo pasa a todos los módulos. Sirven para filtrar en el portal, para ver costos por ambiente y para saber que **no** se debe editar a mano algo gestionado por Terraform.

## 5. Módulo `resource_group`

Archivo: [`infra/modules/resource_group/main.tf`](../infra/modules/resource_group/main.tf).

- **`azurerm_resource_group.this`**: la "carpeta" de Azure. Argumentos: `name`, `location`, `tags`.
- Inputs: `name`, `location`, `tags`.
- Outputs: `name`, `location`, `id`. Los demás módulos usan `name` y `location`, lo que crea la dependencia: todo se crea después del grupo.
- Nota: `this` es solo el nombre local dentro del código; el nombre en Azure es `var.name`.

## 6. Módulo `acr`

Archivo: [`infra/modules/acr/main.tf`](../infra/modules/acr/main.tf).

- **`azurerm_container_registry.this`**: el registro privado de imágenes Docker (donde `docker push` dejará la imagen en el capítulo de CD).
  - `sku`: `Basic` (dev, ~5 USD/mes), `Standard` (prod) o `Premium`.
  - `admin_enabled = false`: no existe usuario/contraseña compartidos; el acceso es por identidad (ver App Service).
- Inputs: `name` (con `validation` de formato), `resource_group_name`, `location`, `sku`, `tags`.
- Outputs: `id` (para el rol), `name`, `login_server` (`<name>.azurecr.io`, prefijo de las imágenes).

## 7. Módulo `monitoring`

Archivo: [`infra/modules/monitoring/main.tf`](../infra/modules/monitoring/main.tf).

- **`azurerm_log_analytics_workspace.this`**: almacén de logs. `sku = "PerGB2018"` (pago por GB), `retention_in_days` (30 en dev, 90 en prod).
- **`azurerm_application_insights.this`**: monitoriza la API. `workspace_id` lo enlaza al workspace anterior (dependencia implícita) y `application_type = "web"`.
- Outputs: `workspace_id` y `connection_string` (marcado `sensitive`).

## 8. Módulo `app_service`

Archivo: [`infra/modules/app_service/main.tf`](../infra/modules/app_service/main.tf). Es el más importante.

1. **`azurerm_service_plan.this`**: la máquina. `os_type = "Linux"`, `sku_name` (`B1` en dev, `P1v3` en prod).
2. **`azurerm_linux_web_app.this`**: la aplicación.
   - `service_plan_id`: la une al plan (dependencia implícita).
   - `https_only = true`.
   - `identity { type = "SystemAssigned" }`: Azure le crea una **identidad administrada**.
   - `app_settings`: variables de entorno (`WEBSITES_PORT=8080`, cadena de Application Insights).
   - `site_config`: `health_check_path = "/health"` (el endpoint del capítulo 03), `always_on`, `container_registry_use_managed_identity = true` y `application_stack` con la imagen (`docker_registry_url` + `docker_image_name`).
   - `lifecycle { ignore_changes = [...docker_image_name] }`: cuando el pipeline despliegue una imagen nueva, Terraform no la revertirá.
3. **`azurerm_role_assignment.acr_pull`**: da a la identidad de la app el rol `AcrPull` **solo sobre el ACR**. Es lo que permite descargar la imagen sin contraseñas.

Detalle de dependencias: el rol necesita `principal_id` (que existe cuando la app ya está creada), así que Terraform lo crea al final sin `depends_on`.

> La primera vez, la imagen `api:latest` aún no existe en el ACR (lo hará el pipeline de CD), así que la app mostrará error al arrancar. Es normal hasta publicar la primera imagen.

## 9. Cómo se conectan

En [`infra/envs/dev/main.tf`](../infra/envs/dev/main.tf):

```hcl
module "app_service" {
  source              = "../../modules/app_service"
  resource_group_name = module.resource_group.name   # sale de un módulo...
  acr_id              = module.acr.id                # ...otro...
  application_insights_connection_string = module.monitoring.connection_string
  # ...
}
```

Cada `module.X.Y` es una dependencia implícita. Esa es toda la "magia" del orden.

## 10. Ejercicio

Sin ejecutar nada, responde leyendo el código: (a) ¿qué ocurre si cambias `sku = "Basic"` a `"Standard"` en el ACR: se destruye o se modifica? (pista: el plan mostrará `~`); (b) ¿por qué `app_service` recibe `acr_id` y `acr_login_server` por separado? Las respuestas se confirman en [09](09-terraform-ambientes-y-comandos.md) con `terraform plan`.
