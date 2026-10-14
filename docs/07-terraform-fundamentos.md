# 07 - Terraform: fundamentos

En este capítulo aprenderás qué es la infraestructura como código, qué hace Terraform, cómo es su flujo de trabajo y cómo se lee su lenguaje. No hace falta tener cuenta de Azure: aquí solo se explica y se lee código. Los términos están definidos en [00 - Glosario](00-glosario.md).

## 1. Qué problema resuelve

Para publicar la API en Azure necesitas varias piezas: un grupo de recursos, un registro de imágenes (ACR), un servidor (App Service), monitorización... Puedes crearlas a mano haciendo clic en el portal web de Azure, pero:

- Nadie recuerda exactamente qué clics hizo.
- Crear un segundo ambiente (prod) idéntico a dev es repetir todo a mano y se cometen errores.
- No hay historial de quién cambió qué ni revisión antes de cambiarlo.

**Infraestructura como código (IaC)** resuelve esto: escribes la infraestructura en archivos de texto, los guardas en Git, los revisas en pull requests y una herramienta los aplica. **Terraform** es esa herramienta.

Terraform es **declarativo**: no escribes *pasos* ("crea esto, luego aquello"), sino el **estado deseado** ("quiero un ACR llamado X con SKU Basic"). Terraform compara lo que pides con lo que existe y calcula solo qué crear, modificar o borrar.

## 2. Las piezas

| Pieza | Qué es |
| --- | --- |
| **Terraform CLI** | El programa `terraform` que instalaste en el capítulo 01. |
| **Provider** | Plugin que sabe hablar con una plataforma. Aquí `azurerm` (Azure). Se descarga en `terraform init`. |
| **Resource** | Una pieza de infraestructura que Terraform gestiona (un ACR, un App Service...). |
| **Data source** | Lectura de algo que ya existe y que Terraform no gestiona (por ejemplo, tu identidad actual). |
| **State** | Fichero donde Terraform apunta qué recursos reales creó. |
| **Module** | Carpeta reutilizable con recursos relacionados (capítulo 08). |

## 3. El flujo de trabajo

```
 escribir .tf  ->  init  ->  validate  ->  plan  ->  apply  ->  (cambiar .tf)  ->  plan  ->  apply ... ->  destroy
```

| Comando | Qué hace | ¿Modifica Azure? |
| --- | --- | --- |
| `terraform fmt` | Da formato estándar a los `.tf` (sangrado, alineación). | No |
| `terraform init` | Descarga providers y módulos y conecta el backend (dónde se guarda el state). Se ejecuta una vez y cada vez que cambian providers/módulos/backend. | No (crea la carpeta local `.terraform/`) |
| `terraform validate` | Comprueba que la sintaxis y las referencias son coherentes. No consulta Azure. | No |
| `terraform plan` | Compara código, state y realidad y **muestra** qué haría. | No |
| `terraform apply` | Ejecuta los cambios del plan (pide confirmación). | **Sí** |
| `terraform destroy` | Borra todo lo gestionado por ese state. | **Sí** |

La regla de oro: **lee siempre el plan antes de aplicar**. Los comandos exactos y cómo leer un plan están en [09](09-terraform-ambientes-y-comandos.md).

## 4. El state

Terraform necesita recordar qué recursos creó. Lo guarda en el **state** (un JSON, `*.tfstate`). Con él sabe que el ACR `x` de tu código es el ACR real con cierto ID en Azure.

Puntos importantes:

- **Contiene datos sensibles** (por ejemplo, la cadena de conexión de Application Insights en texto plano). Por eso `*.tfstate` está en `.gitignore` y **nunca** se sube a Git.
- Por defecto el state es un fichero local. Eso no sirve para trabajo en equipo ni para pipelines, así que usamos un **backend remoto**: una cuenta de Azure Storage (se crea en [`infra/bootstrap`](../infra/bootstrap/README.md)).
- El backend remoto hace **locking**: mientras alguien ejecuta `apply`, el blob queda bloqueado y un segundo `apply` espera o falla. Así dos personas no corrompen el state.
- Cada ambiente tiene **su propio** fichero de state (`dev.tfstate`, `prod.tfstate`), así un error en dev no afecta a prod.
- Nunca edites el state a mano.

## 5. Providers y versiones

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

- `required_version`: versión mínima de la herramienta.
- `source`: de dónde se descarga el provider (el registro público de HashiCorp).
- `version = "~> 4.0"`: acepta `4.x` pero no `5.0`.

`terraform init` escribe el fichero **`.terraform.lock.hcl`**, que fija la versión exacta y los hashes de cada provider descargado. **Se sube a Git** para que todos (y el pipeline) usen exactamente los mismos plugins.

El provider se configura aparte:

```hcl
provider "azurerm" {
  features {}                           # obligatorio, aunque vaya vacío
  subscription_id = var.subscription_id # obligatorio desde azurerm 4.x
}
```

## 6. Sintaxis HCL

Terraform usa un lenguaje llamado **HCL**. Hay solo dos construcciones: **argumentos** (`clave = valor`) y **bloques** (`tipo "etiqueta" { ... }`).

```hcl
# Esto es un comentario

resource "azurerm_resource_group" "this" {   # bloque: tipo + nombre local
  name     = "rg-demo"                        # argumento
  location = "westeurope"
  tags     = { env = "dev" }                  # mapa
}
```

### Tipos de bloque que verás en el repo

| Bloque | Para qué | Ejemplo |
| --- | --- | --- |
| `terraform` | Versiones y backend. | `terraform { required_version = ... }` |
| `provider` | Configurar un provider. | `provider "azurerm" { ... }` |
| `resource` | Crear y gestionar algo. | `resource "azurerm_container_registry" "this" { ... }` |
| `data` | Leer algo existente. | `data "azurerm_client_config" "current" {}` |
| `variable` | Parámetro de entrada. | `variable "location" { type = string }` |
| `locals` | Valores calculados internos (como constantes). | `locals { prefix = "${var.project}-${var.environment}" }` |
| `output` | Valor que se muestra / devuelve. | `output "app_url" { value = ... }` |
| `module` | Usar un módulo. | `module "acr" { source = "../../modules/acr" }` |

### Referencias

| Escribes | Significa |
| --- | --- |
| `var.location` | Valor de la variable `location`. |
| `local.prefix` | Valor del local `prefix`. |
| `azurerm_resource_group.this.name` | Atributo `name` del recurso `this` de ese tipo. |
| `module.acr.login_server` | Output `login_server` del módulo `acr`. |
| `data.azurerm_client_config.current.tenant_id` | Atributo de un data source. |
| `"${var.project}-dev"` | Interpolación: mete un valor dentro de un texto. |

### Tipos de datos

`string` (`"texto"`), `number` (`3`), `bool` (`true`), `list(string)` (`["a", "b"]`), `map(string)` (`{ a = "x" }`).

### Funciones útiles (las verás en el código)

`replace("a-b", "-", "")` quita guiones; `lower()`; `merge(mapa1, mapa2)` combina diccionarios; `contains(lista, valor)`; `can(regex(...))` comprueba un patrón.

## 7. Dependencias

Terraform construye un **grafo** y decide el orden solo.

- **Dependencia implícita**: si un recurso usa un atributo de otro (`service_plan_id = azurerm_service_plan.this.id`), Terraform crea primero el segundo. Es lo normal y lo preferible.
- **`depends_on`**: dependencia explícita, solo para cuando la relación existe pero no se ve en ningún atributo. Úsalo poco.
- Lo que no depende de nada se crea **en paralelo**.

## 8. Variables, locals, outputs y sensibles

- **Variables** reciben valores: de `terraform.tfvars`, de `-var "x=y"` o de variables de entorno `TF_VAR_x`. Orden de prioridad: `-var` > `*.tfvars` > `TF_VAR_*` > `default`.
- **`validation`** dentro de una variable rechaza valores inválidos pronto, con un mensaje claro.
- **`sensitive = true`** oculta un valor en la consola. No lo cifra en el state.
- **`lifecycle`** ajusta cómo se trata un recurso: `ignore_changes` (ignora cambios externos en ciertos atributos), `prevent_destroy` (bloquea su borrado), `create_before_destroy`.
- **Tags**: etiquetas clave/valor en los recursos para saber de qué proyecto/ambiente son y a quién imputar el costo.

## 9. Organización de ficheros

Terraform lee **todos** los `.tf` de una carpeta como si fueran uno solo; separarlos es solo orden. Convención de este repo:

| Fichero | Contenido |
| --- | --- |
| `versions.tf` / `providers.tf` | Versiones y configuración de providers. |
| `backend.tf` | Dónde se guarda el state. |
| `main.tf` | Recursos o llamadas a módulos. |
| `variables.tf` | Declaración de variables. |
| `outputs.tf` | Declaración de outputs. |
| `terraform.tfvars` | Valores concretos de las variables (sin secretos). |

```
infra/
  bootstrap/      # crea el almacenamiento del state (script az, una vez)
  modules/        # piezas reutilizables (capítulo 08)
  envs/
    dev/          # un "directorio raíz" por ambiente
    prod/
```

Cada carpeta de `envs/` es un **directorio raíz**: el lugar donde ejecutas `terraform init/plan/apply`. Tiene su propio state.

## 10. Qué sigue

- [08 - Módulos](08-terraform-modulos.md): cómo está dividida la infraestructura de la API.
- [09 - Ambientes y comandos](09-terraform-ambientes-y-comandos.md): ejecutar todo, con costos y errores comunes.
