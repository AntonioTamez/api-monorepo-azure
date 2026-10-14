# 10 - Identidad GitHub ↔ Azure con OIDC (sin contraseñas)

Requisitos: capítulos [06](06-github-actions.md) (workflows) y [09](09-terraform-ambientes-y-comandos.md) (ya hiciste `apply` de `dev`). Los términos están en el [glosario](00-glosario.md).

> **Aviso de costos.** Este capítulo no crea recursos de pago: las identidades y los roles de Entra ID son gratuitos. Solo configuras permisos.
>
> **Aviso de verificación.** Los scripts de este capítulo se escribieron sin poder ejecutarlos contra Azure. Léelos antes de correrlos y, si un comando difiere en tu versión de `az`, `az <comando> --help` es la fuente de verdad.

## 1. El problema: ¿cómo entra GitHub a tu Azure?

Los workflows de CD (capítulo [11](11-cd-y-ambientes.md)) necesitan hacer cosas en Azure: subir imágenes al ACR, desplegar la web app, ejecutar Terraform. Pero el runner de GitHub es una máquina ajena: Azure no sabe quién es. Hay dos formas de presentarla:

| Forma | Cómo funciona | Problema |
| --- | --- | --- |
| **Secreto de cliente** (la forma antigua) | Creas una contraseña para una cuenta de servicio y la guardas en un secret de GitHub | La contraseña **caduca** (hay que rotarla), puede **filtrarse** (logs, fork, ex-compañero) y vale desde cualquier sitio |
| **OIDC** (la forma moderna, la que usamos) | GitHub firma un **token de corta duración** que dice "soy este repo, este job"; Azure comprueba la firma y las reglas que tú configuraste | No existe ninguna contraseña que guardar, rotar ni filtrar |

**OIDC (OpenID Connect)** es un estándar para demostrar identidad con tokens firmados. Aquí significa: *Azure confía en GitHub (el emisor) solo bajo las condiciones que tú definas*.

## 2. Conceptos de Azure que necesitas

| Concepto | Qué es | ¿Secreto? |
| --- | --- | --- |
| **Tenant** | Tu "organización" en Microsoft Entra ID (el directorio de identidades). Tiene un **Tenant ID** | No |
| **Subscription** | El contenedor donde se factura y se crean recursos. Tiene un **Subscription ID** | No |
| **App registration** | La "ficha" de una aplicación en Entra ID. Tiene un **Client ID** (o Application ID) | No |
| **Service principal** | La cuenta de servicio concreta, dentro de tu tenant, que recibe permisos. Se crea a partir de la app registration | No |
| **Federated credential** | Regla en la app registration: "acepta tokens del emisor X cuyo *subject* sea Y" | No |
| **Role assignment** | "Esta identidad tiene este rol sobre este ámbito" | No |

**Los tres IDs (tenant, subscription y client) NO son secretos.** Son direcciones, no llaves: saber que existe la puerta número 42 no te deja entrar. Lo que protege el acceso son las *reglas de confianza* (credenciales federadas) y los *roles*. Por eso en GitHub los guardamos como **variables** (visibles en los logs) y no como secrets. Un atacante que los conozca no puede hacer nada sin un token firmado por GitHub desde **tu** repositorio.

## 3. Cómo fluye el login (diagrama)

```mermaid
sequenceDiagram
    participant R as Runner de GitHub (tu job)
    participant G as GitHub (emisor OIDC)
    participant E as Microsoft Entra ID
    participant A as Azure (ACR, App Service...)
    R->>G: 1. Dame un token para este job (permiso id-token: write)
    G-->>R: 2. Token firmado: subject = repo:OWNER/REPO:environment:dev
    R->>E: 3. Aquí está el token; quiero entrar como el service principal (client id)
    E->>E: 4. ¿Firma válida? ¿issuer y subject coinciden con una credencial federada?
    E-->>R: 5. Token de acceso de Azure (dura ~1 hora)
    R->>A: 6. Operaciones con ese token (según los roles asignados)
```

El **subject** es el texto que identifica *desde dónde* corre el job. Debe coincidir **exactamente** con una credencial federada:

| Cuándo corre el job | Subject que genera GitHub |
| --- | --- |
| El job declara `environment: dev` | `repo:OWNER/REPO:environment:dev` |
| El job declara `environment: prod` | `repo:OWNER/REPO:environment:prod` |
| Job en un pull request (sin environment) | `repo:OWNER/REPO:pull_request` |
| Job en un push a master (sin environment) | `repo:OWNER/REPO:ref:refs/heads/master` |

Importante: si el job declara `environment`, el subject usa el environment **aunque** corra en master. Los pull requests desde *forks* no reciben token OIDC (GitHub lo impide a propósito).

## 4. Qué crea `infra/identity`

Dos scripts equivalentes: [`setup-github-oidc.ps1`](../infra/identity/setup-github-oidc.ps1) (Windows) y [`setup-github-oidc.sh`](../infra/identity/setup-github-oidc.sh) (bash). Elegimos `az` (y no Terraform) por sencillez: crear la identidad con Terraform tendría un problema de "huevo y gallina" (la identidad que ejecuta Terraform no puede crearse a sí misma) y necesitaría un provider más (`azuread`). Alternativa avanzada: el recurso `azuread_application_federated_identity_credential` hace lo mismo; queda como ejercicio.

Crea **una** app registration, `sp-devopslab-github`, con estas piezas:

**Credenciales federadas**

| Nombre | Subject | Para qué |
| --- | --- | --- |
| `github-env-dev` | `repo:OWNER/REPO:environment:dev` | Jobs de CD y Terraform apply de dev |
| `github-env-prod` | `repo:OWNER/REPO:environment:prod` | Ídem para prod (con aprobación manual) |
| `github-pull-request` | `repo:OWNER/REPO:pull_request` | `terraform plan` en pull requests |
| `github-branch-master` | `repo:OWNER/REPO:ref:refs/heads/master` | Jobs en master sin environment (reservada para usos futuros) |

**Roles (mínimo privilegio: cada rol en el ámbito más pequeño posible)**

| Rol | Ámbito | Por qué |
| --- | --- | --- |
| `Contributor` | Grupo de recursos `rg-devopslab-dev` y `-prod` | Terraform crea y cambia recursos; el deploy cambia la web app. **No** da permiso sobre el resto de la suscripción |
| `Role Based Access Control Administrator` | Ídem | Nuestro Terraform crea una asignación de rol (`AcrPull` de la web app). `Contributor` **no** puede crear asignaciones de rol, y `terraform apply` fallaría con `AuthorizationFailed ... roleAssignments/write` |
| `AcrPush` | El ACR de cada ambiente | Subir imágenes (`docker push`). También permite descargarlas |
| `Storage Blob Data Contributor` | La cuenta de Storage del state | Leer/escribir `dev.tfstate` y `prod.tfstate` y su bloqueo (lease) |

## 5. Paso a paso

### 5.1 Orden obligatorio

1. [Bootstrap](../infra/bootstrap/README.md) del state (cuenta de Storage).
2. `terraform apply` **local** de `dev` (capítulo 09). Este primer `apply` lo haces tú porque la identidad de GitHub aún no existe, y además necesita que el grupo de recursos y el ACR ya existan para asignarles roles. Haz lo mismo con `prod` si vas a usarlo (cuesta dinero).
3. Este capítulo: crear la identidad.

### 5.2 Ejecutar el script

Necesitas tu usuario con permiso para crear apps en Entra ID y para asignar roles (rol `Owner` o `User Access Administrator` en la suscripción). Si usas una cuenta personal de laboratorio, normalmente ya lo tienes.

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
./infra/identity/setup-github-oidc.ps1 `
  -Repository "TU-USUARIO/api-monorepo-azure" `
  -StateAccount "stdevopslabtfa1b2" `
  -Environments dev          # quita este parámetro si ya aplicaste dev y prod
```

(`TU-USUARIO/api-monorepo-azure` debe coincidir **letra por letra** con la URL de GitHub: `https://github.com/TU-USUARIO/api-monorepo-azure`, incluidas mayúsculas.)

Equivalente en bash:

```bash
ENVIRONMENTS="dev" ./infra/identity/setup-github-oidc.sh TU-USUARIO/api-monorepo-azure stdevopslabtfa1b2
```

Salida esperada (recortada):

```
App registration creada: sp-devopslab-github
Service principal creado.
Credencial creada: github-env-dev  ->  repo:TU-USUARIO/api-monorepo-azure:environment:dev
Credencial creada: github-pull-request  ->  repo:TU-USUARIO/api-monorepo-azure:pull_request
...
Rol asignado: Contributor  en  /subscriptions/.../resourceGroups/rg-devopslab-dev
Rol asignado: AcrPush  en  /subscriptions/.../registries/devopslabdevk3x9
Listo. Guarda estos valores como VARIABLES (no secretos) en GitHub:
  AZURE_CLIENT_ID       = 00000000-0000-0000-0000-000000000000
  ...
```

El script es **idempotente**: si lo repites, dice "ya existía" y sigue. Así puedes volver a ejecutarlo cuando crees `prod`.

### 5.3 Verificar

```powershell
az ad app federated-credential list --id "<AZURE_CLIENT_ID>" --query "[].{name:name,subject:subject}" --output table
az role assignment list --assignee "<AZURE_CLIENT_ID>" --all --query "[].{rol:roleDefinitionName,ambito:scope}" --output table
```

Deberías ver las 3-4 credenciales y los roles de la tabla anterior.

## 6. Configurar GitHub

Hay dos niveles de configuración:

- **Repository variables**: valen para todo el repositorio.
- **Environment**: un "entorno" nombrado (`dev`, `prod`) con sus propias variables, reglas de aprobación y restricción de ramas.

### 6.1 Variables del repositorio (UI)

`Settings` → `Secrets and variables` → `Actions` → pestaña **Variables** → `New repository variable`. Crea:

| Variable | Valor | De dónde sale |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | Client ID | Lo imprime el script |
| `AZURE_TENANT_ID` | Tenant ID | Lo imprime el script (también `terraform output tenant_id`) |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | Lo imprime el script |
| `TFSTATE_RESOURCE_GROUP` | `rg-devopslab-tfstate` | Bootstrap |
| `TFSTATE_STORAGE_ACCOUNT` | `stdevopslabtfa1b2` | Bootstrap |
| `BUILD_ACR_NAME` | Nombre del ACR de **dev** | `terraform -chdir=infra/envs/dev output -raw acr_name`. Las imágenes se construyen una vez y se publican aquí |

Opcional: `ENABLE_PROD` = `true` activa `prod` en los workflows de plan, apply y deploy (capítulo [11](11-cd-y-ambientes.md)). Si no existe o vale otra cosa, los workflows solo tocan `dev`, y así no gastas dinero por accidente.

> No hace falta ningún *secret*. Si algún tutorial te pide `AZURE_CLIENT_SECRET`, es la forma antigua: aquí no existe.

Con GitHub CLI (**solo como referencia; esto escribe en GitHub, ejecútalo tú cuando estés listo**):

```powershell
gh auth login
gh variable set AZURE_CLIENT_ID --body "<CLIENT_ID>" --repo TU-USUARIO/api-monorepo-azure
gh variable set AZURE_TENANT_ID --body "<TENANT_ID>" --repo TU-USUARIO/api-monorepo-azure
gh variable set AZURE_SUBSCRIPTION_ID --body "<SUBSCRIPTION_ID>" --repo TU-USUARIO/api-monorepo-azure
gh variable set TFSTATE_RESOURCE_GROUP --body "rg-devopslab-tfstate" --repo TU-USUARIO/api-monorepo-azure
gh variable set TFSTATE_STORAGE_ACCOUNT --body "<CUENTA_STATE>" --repo TU-USUARIO/api-monorepo-azure
gh variable set BUILD_ACR_NAME --body "<ACR_DEV>" --repo TU-USUARIO/api-monorepo-azure
```

### 6.2 Crear los environments (UI)

`Settings` → `Environments` → `New environment`:

1. Crea **`dev`**. Sin reglas: los jobs que lo usan corren solos.
2. Crea **`prod`**. Marca **Required reviewers** y añádete a ti (o a tu equipo). Opcional: **Deployment branches and tags** → *Selected branches* → `master`, para que solo master pueda desplegar a prod.

Cuando un job declara `environment: prod`, GitHub **lo pausa** hasta que un revisor pulse *Approve and deploy*. Eso es la "aprobación manual".

> Los nombres deben ser exactamente `dev` y `prod`: forman parte del subject (`...:environment:prod`).
>
> Los *required reviewers* en repositorios privados requieren plan de pago de GitHub (Team o Enterprise); en repositorios públicos son gratuitos. Si tu plan no los ofrece, `prod` simplemente no pedirá aprobación (ejercicio 3 del capítulo 12 trata esto).

### 6.3 Variables de cada environment (UI)

Dentro de cada environment → **Environment variables**:

| Variable | Valor en `dev` | Valor en `prod` |
| --- | --- | --- |
| `RESOURCE_GROUP` | `terraform output -raw resource_group_name` de dev | ídem de prod |
| `ACR_NAME` | `terraform output -raw acr_name` de dev | ídem de prod |
| `APP_NAME` | `terraform output -raw app_name` de dev | ídem de prod |

Con el mismo nombre de variable y valores distintos por environment, el **mismo workflow** sirve para ambos. En CLI (referencia):

```powershell
$repo = "TU-USUARIO/api-monorepo-azure"
gh variable set RESOURCE_GROUP --env dev --body "rg-devopslab-dev" --repo $repo
gh variable set ACR_NAME       --env dev --body "<ACR_DEV>"        --repo $repo
gh variable set APP_NAME       --env dev --body "<APP_DEV>"        --repo $repo
```

Crear el environment `prod` con revisores por CLI usa la API REST (necesitas el ID numérico de tu usuario):

```powershell
$userId = gh api users/TU-USUARIO --jq .id
@{ reviewers = @(@{ type = "User"; id = [int]$userId }) } | ConvertTo-Json -Depth 4 |
  gh api --method PUT repos/TU-USUARIO/api-monorepo-azure/environments/prod --input -
```

## 7. Seguridad: qué protege y qué no

- **Sin contraseñas**: no hay nada que rotar ni filtrar. El token de GitHub dura minutos.
- **Subject exacto**: otro repositorio (o un fork) no puede obtener un token que Azure acepte para el tuyo.
- **Permisos mínimos**: `permissions: id-token: write` solo en los jobs que lo necesitan.
- **Limitación consciente**: usamos *una sola* identidad para dev y prod por sencillez. Eso significa que un job de un pull request (credencial `pull_request`) tendría, técnicamente, el mismo `Contributor` sobre prod. Con protección de rama y revisión de PR el riesgo es bajo en un laboratorio, pero en una empresa se separa: una identidad por ambiente y una identidad de **solo lectura** (`Reader`) para `terraform plan`. Es el ejercicio 7 del capítulo 12.
- **Endurecer más**: limitar el rol RBAC Administrator con una *condición* para que solo pueda asignar `AcrPull`.

## 8. Errores comunes

| Mensaje | Causa y solución |
| --- | --- |
| `AADSTS70021: No matching federated identity record found` | El *subject* del token no coincide con ninguna credencial. Revisa mayúsculas del repo, que el environment se llame igual y si el job declara `environment` o no. El mensaje de error muestra el subject real: compáralo con `az ad app federated-credential list` |
| `AADSTS700016: Application with identifier ... was not found` | `AZURE_CLIENT_ID` o `AZURE_TENANT_ID` incorrectos |
| `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable` | Falta `permissions: id-token: write` en el job/workflow |
| `Insufficient privileges to complete the operation` al ejecutar el script | Tu usuario no puede crear apps en Entra ID. Pide a un administrador del tenant el rol `Application Administrator` |
| `AuthorizationFailed ... roleAssignments/write` en `terraform apply` | Falta `Role Based Access Control Administrator` en el grupo de recursos |
| `AuthorizationPermissionMismatch` en `terraform init` (Actions) | Falta `Storage Blob Data Contributor` sobre la cuenta del state, o el rol aún no se propagó (espera unos minutos) |
| `ResourceGroupNotFound` al ejecutar el script | Aún no hiciste el primer `apply` de ese ambiente; usa `-Environments dev` |
| Las variables aparecen vacías en el workflow | Las definiste en otro nivel (repositorio vs environment) o con otro nombre; los nombres distinguen mayúsculas |

## 9. Ejercicios

1. Ejecuta el script con un repositorio inventado y mira que las credenciales se crean con ese subject. Bórralas con `az ad app federated-credential delete` y vuelve a crearlas bien.
2. Lista tus asignaciones de rol (5.3). ¿Cuál es el ámbito más amplio? ¿Por qué ninguna es de suscripción completa?
3. Busca en el portal: `Microsoft Entra ID` → `App registrations` → tu app → `Certificates & secrets`. Comprueba que **no** hay secretos de cliente.
