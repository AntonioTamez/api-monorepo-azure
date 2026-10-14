# 09 - Terraform: ambientes y comandos

Requisitos: capítulos [07](07-terraform-fundamentos.md) y [08](08-terraform-modulos.md). Aquí ejecutas Terraform de verdad.

> **Aviso de costos.** `apply` crea recursos de pago en Azure. Mientras no hagas `apply` no se cobra nada. `validate` y `plan` son gratis. Cuando termines, ejecuta `terraform destroy`.

| Ambiente | ACR | App Service Plan | Costo aproximado* |
| --- | --- | --- | --- |
| `dev` | Basic | **B1** (Basic) | ~ 17-20 USD/mes |
| `prod` | Standard | **P1v3** (Premium v3) | ~ 120-140 USD/mes |

\* Orientativo y variable por región y fecha; consulta el [calculador de precios de Azure](https://azure.microsoft.com/pricing/calculator/). Application Insights y Log Analytics cobran por datos ingeridos (en un laboratorio, céntimos). El nivel gratuito **F1** existe para App Service, pero tiene cuotas diarias de CPU, no admite `always_on` y no es adecuado para contenedores personalizados, así que no se usa aquí. Si solo estás aprendiendo, **haz `plan` en prod pero no `apply`**.

## 1. Estructura

```
infra/
  bootstrap/            # script que crea el almacenamiento del state (una vez)
  modules/              # resource_group, acr, monitoring, app_service
  envs/
    dev/                # providers.tf backend.tf main.tf variables.tf outputs.tf terraform.tfvars
    prod/               # lo mismo, con valores más grandes
```

Cada ambiente es independiente: su propio state (`dev.tfstate` / `prod.tfstate`) y su propio grupo de recursos (`rg-devopslab-dev` / `rg-devopslab-prod`). Se diferencian solo en `terraform.tfvars`:

| Variable | dev | prod |
| --- | --- | --- |
| `acr_sku` | Basic | Standard |
| `app_service_sku` | B1 | P1v3 |
| `always_on` | false | true |
| `log_retention_days` | 30 | 90 |

## 2. Preparación (una sola vez)

1. Instala y verifica `az` y `terraform` ([01](01-requisitos-y-setup.md)).
2. Inicia sesión y elige suscripción:

```powershell
az login
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID>"
```

3. Crea el almacenamiento del state ([`infra/bootstrap`](../infra/bootstrap/README.md)):

```powershell
./infra/bootstrap/create-state-backend.ps1 -Suffix a1b2
```

Anota el nombre de la cuenta que imprime (por ejemplo `stdevopslabtfa1b2`).

4. Guarda el ID de suscripción en una variable de entorno (la lee Terraform como `var.subscription_id`):

```powershell
$env:TF_VAR_subscription_id = "<SUBSCRIPTION_ID>"
```

## 3. Comandos, paso a paso (ejemplo con dev)

Ejecuta desde la raíz del repositorio. `-chdir` hace que Terraform trabaje en esa carpeta.

### 3.1 Formato

```powershell
terraform fmt -recursive infra          # reescribe los .tf con el formato estándar
terraform fmt -check -recursive infra   # solo comprueba (lo usa CI); falla si hay diferencias
```

### 3.2 Init

```powershell
terraform -chdir=infra/envs/dev init `
  -backend-config="resource_group_name=rg-devopslab-tfstate" `
  -backend-config="storage_account_name=stdevopslabtfa1b2" `
  -backend-config="container_name=tfstate"
```

Qué hace: descarga los providers `azurerm` y `random`, copia los módulos, conecta con el blob del state y crea `.terraform.lock.hcl` (**súbelo a Git**). Esperas ver `Terraform has been successfully initialized!`.

*Atajo para aprender sin Azure*: `terraform -chdir=infra/envs/dev init -backend=false` omite el backend (el state sería local). Sirve para `validate`, no para `plan/apply` reales.

### 3.3 Validate

```powershell
terraform -chdir=infra/envs/dev validate
```

Salida esperada: `Success! The configuration is valid.` No habla con Azure.

### 3.4 Plan

```powershell
terraform -chdir=infra/envs/dev plan -out=dev.tfplan
```

`-out` guarda el plan en un fichero (`*.tfplan` está ignorado en Git) para aplicar **exactamente** lo que revisaste.

### 3.5 Apply

```powershell
terraform -chdir=infra/envs/dev apply dev.tfplan
```

Al pasar un plan guardado no pide confirmación. Sin plan (`terraform apply`) muestra el plan y pregunta `yes`. Tarda unos minutos.

### 3.6 Output

```powershell
terraform -chdir=infra/envs/dev output                                   # todos (los sensibles salen ocultos)
terraform -chdir=infra/envs/dev output -raw app_url                      # un valor, sin comillas
terraform -chdir=infra/envs/dev output -raw application_insights_connection_string
```

### 3.7 Destroy

```powershell
terraform -chdir=infra/envs/dev plan -destroy      # ver qué se borraría
terraform -chdir=infra/envs/dev destroy            # pide confirmación (escribe yes)
```

Repite los pasos con `infra/envs/prod` y `key = prod.tfstate` (ya está en su `backend.tf`) para prod.

## 4. Leer un plan

Cada línea empieza con un símbolo:

| Símbolo | Significado |
| --- | --- |
| `+` | Se **creará** |
| `-` | Se **destruirá** |
| `~` | Se **modificará** en el sitio |
| `-/+` | Se **destruirá y volverá a crear** (reemplazo) |
| `<=` | Se leerá (data source) |

Ejemplo recortado:

```
  # module.acr.azurerm_container_registry.this will be created
  + resource "azurerm_container_registry" "this" {
      + admin_enabled = false
      + name          = "devopslabdevk3x9"
      + sku           = "Basic"
      ...
    }

Plan: 8 to add, 0 to change, 0 to destroy.
```

Cómo leerlo:

1. Mira primero el **resumen final** (`Plan: X to add, Y to change, Z to destroy`).
2. Desconfía de todo `destroy` y de todo `-/+` que no esperabas: puede borrar datos.
3. `(known after apply)` significa que el valor lo asignará Azure al crear (IDs, por ejemplo).
4. `(sensitive value)` es un valor oculto.
5. Si el plan dice `No changes`, tu código y la realidad coinciden.

## 5. State y locking

- El state vive en el blob `tfstate/dev.tfstate` de tu cuenta de Storage. Mientras corre `apply`, Azure bloquea ese blob (**lease**): un segundo `apply` espera o falla con `Error acquiring the state lock`.
- Ver qué gestiona Terraform: `terraform -chdir=infra/envs/dev state list`.
- Si un `apply` se interrumpe y el bloqueo queda "colgado": `terraform force-unlock <LOCK_ID>` (el ID aparece en el error). Hazlo solo si estás seguro de que nadie más está ejecutando Terraform.
- Nunca edites ni borres el blob del state a mano; si lo pierdes, Terraform "olvida" lo que creó e intentará crearlo de nuevo (y fallará porque ya existe). El versionado activado en el bootstrap permite recuperar una versión anterior.

## 6. Drift (desviación)

Si alguien cambia algo a mano en el portal (por ejemplo, cambia el SKU del ACR), la realidad deja de coincidir con el código. Para verlo:

```powershell
terraform -chdir=infra/envs/dev plan
```

Terraform refresca el state contra Azure y propone volver a lo que dice el código (`~`). Opciones: aplicar (el código manda) o actualizar el código para reflejar el cambio. Por eso: **todo cambio de infraestructura se hace en código y pasa por pull request**.

## 7. Errores comunes

| Mensaje | Causa y solución |
| --- | --- |
| `terraform: command not found` | Terraform no está instalado o falta en el `PATH`; reabre la terminal ([01](01-requisitos-y-setup.md)). |
| `subscription_id is a required provider property` / `No value for required variable` | Falta `$env:TF_VAR_subscription_id`. |
| `Error: Backend initialization required` | Cambió el backend o no hiciste `init`; ejecuta `init` de nuevo. |
| `403 ... AuthorizationPermissionMismatch` en `init` | Tu usuario no tiene `Storage Blob Data Contributor` sobre la cuenta del state (o el rol aún no se propagó: espera 2 minutos). |
| `Please run 'az login'` / `AADSTS...` | Sesión caducada: `az login`. |
| `Error acquiring the state lock` | Otra ejecución está en curso o quedó un bloqueo; ver sección 5. |
| `The registry name ... is already in use` / `... is not available` | El nombre global ya existe. El sufijo aleatorio lo evita; si choca, cambia `project` en `terraform.tfvars`. |
| `Provider produced inconsistent result` o `Error: Unsupported argument` | Versión del provider distinta a la esperada: haz `terraform init -upgrade` y revisa el cambio. |
| `The subscription is not registered to use namespace 'Microsoft.Web'` | Registra el proveedor: `az provider register --namespace Microsoft.Web` (idem `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`, `Microsoft.Insights`). |
| `This request is not authorized to perform this operation... role assignments` | Tu usuario necesita `Owner` o `User Access Administrator` en la suscripción para crear el `AcrPull`. |
| `quota`/`Operation cannot be completed without additional quota` | Tu suscripción no tiene cuota de ese SKU en la región; prueba otra región o SKU. |
| La web devuelve `503`/error de contenedor | Normal hasta que exista la imagen `api:latest` en el ACR (la publica el CD). |

## 8. Ejercicios

1. Ejecuta `fmt`, `init -backend=false` y `validate` en `dev` y `prod` (no requieren Azure).
2. Con Azure: `plan` en dev y cuenta cuántos recursos se crean (debería ser 8 incluyendo `random_string`). ¿Puedes nombrarlos?
3. Cambia `acr_sku` a `Standard` en dev: ¿el plan muestra `~` o `-/+`?
4. Haz `destroy` de dev y comprueba en el portal que `rg-devopslab-dev` desapareció.
