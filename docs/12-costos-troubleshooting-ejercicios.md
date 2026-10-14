# 12 - Costos, limpieza, troubleshooting y ejercicios

Último capítulo. Aquí aprendes a **no llevarte sustos en la factura**, a diagnosticar errores y a practicar todo lo anterior. Términos en el [glosario](00-glosario.md).

## 1. Costos

> **Disclaimer.** Los precios son **orientativos**, en USD/mes aproximados, y varían por región, moneda, fecha, tipo de contrato y descuentos. Los valores se redondearon a partir de tarifas públicas de la región `westeurope`. **Antes de crear nada, consulta el [calculador de precios de Azure](https://azure.microsoft.com/pricing/calculator/)** y tu propia suscripción (`Cost Management`). Si el precio real difiere de esta tabla, manda el precio real.

Azure cobra por **tiempo que el recurso existe** (aunque nadie lo use), no por uso real, salvo en servicios que miden datos (logs, transferencia).

| Recurso | SKU en dev | ≈ USD/mes dev | SKU en prod | ≈ USD/mes prod | Cómo se cobra |
| --- | --- | --- | --- | --- | --- |
| App Service Plan | B1 (1 núcleo, 1,75 GB) | 12-14 | P1v3 | 100-125 | Por hora que el plan existe, **aunque la app esté parada** |
| Container Registry | Basic | ~5 | Standard | ~20 | Cuota diaria fija + almacenamiento extra |
| Log Analytics | Pay-as-you-go | ~0 en un laboratorio | ídem | céntimos-pocos USD | Por GB ingerido (los primeros 5 GB/mes suelen ser gratis) |
| Application Insights | Sobre Log Analytics | ~0 en un laboratorio | ídem | céntimos-pocos USD | Por GB ingerido |
| Storage del state | Standard LRS | < 0,10 | (compartido) | - | Por GB almacenado y operaciones; un state pesa KB |
| Identidad Entra ID / roles | - | 0 | - | 0 | Gratuito |
| GitHub Actions | - | 0 | - | 0 | Repos públicos: gratis. Privados: minutos gratis según plan y después se cobra |
| **Total aproximado** | | **17-20** | | **120-150** | |

Cómo ahorrar mientras aprendes:

- Trabaja **solo con `dev`** y deja `ENABLE_PROD` sin definir. Para prod, haz `plan` pero no `apply`.
- **Destruye al terminar la sesión de estudio** (sección 2). Recrear con Terraform tarda minutos y cuesta nada.
- Parar la web app (`az webapp stop`) **no ahorra** casi nada: el plan sigue facturando. Lo que ahorra es borrar el plan.
- Crea una alerta de presupuesto **antes** del primer `apply` (sección 3).

## 2. Dejar de gastar: destruir recursos

Orden recomendado (de lo que depende de otras cosas a lo que sustenta todo):

1. **Ambientes** (los recursos de pago). Desde la raíz del repo, con `TF_VAR_subscription_id` definida (capítulo 09):

```powershell
terraform -chdir=infra/envs/prod plan -destroy     # solo si lo creaste; revisa qué se borrará
terraform -chdir=infra/envs/prod destroy           # escribe yes
terraform -chdir=infra/envs/dev plan -destroy
terraform -chdir=infra/envs/dev destroy
```

   Salida esperada al final: `Destroy complete! Resources: 8 destroyed.` (el número puede variar).

2. **Identidad OIDC** (gratuita, pero límpiala si abandonas el laboratorio):

```powershell
az ad app delete --id "<AZURE_CLIENT_ID>"
```

3. **Almacenamiento del state**, solo cuando ya no vayas a usar Terraform (se pierde el state): 

```powershell
az group delete --name rg-devopslab-tfstate --yes --no-wait
```

4. **Verifica** que no quedó nada de pago:

```powershell
az group list --query "[?starts_with(name,'rg-devopslab')].name" --output table
```

   Debe salir vacío.

Plan B si `terraform destroy` falla (state perdido, error raro): borrar el grupo de recursos entero, que elimina todo lo que contiene:

```powershell
az group delete --name rg-devopslab-dev --yes --no-wait
az group delete --name rg-devopslab-prod --yes --no-wait
```

Después, limpia lo que quede en GitHub si quieres: variables, environments y (para no ver ejecuciones fallidas) desactiva `terraform-apply.yml` en *Actions*.

> `az group delete` es **irreversible** y borra todo lo que haya dentro. Verifica el nombre antes de pulsar Enter.

## 3. Presupuestos y alertas (Azure Cost Management)

Un **presupuesto** (budget) no corta el gasto: **avisa por correo** cuando se acerca a un límite. Pasos en el portal:

1. Portal de Azure → busca **Cost Management + Billing** → **Cost Management** → **Budgets** → **+ Add**.
2. Ámbito: tu suscripción (o solo el grupo de recursos `rg-devopslab-dev`).
3. Nombre: `budget-devopslab`; periodo: mensual; importe: por ejemplo **25 USD**.
4. **Alert conditions**: 50 %, 80 % y 100 % del importe real; añade tu correo.
5. Crear. Las alertas pueden tardar hasta 24 h en reflejar el gasto (el cobro se calcula con retraso).

También conviene mirar **Cost analysis** (misma sección) agrupado por *Resource group* para ver qué cuesta qué. Existe `az consumption budget create`, pero configurar las notificaciones por línea de comandos es incómodo; para aprender, usa el portal.

## 4. Troubleshooting: tabla de errores reales

Método general: **lee el primer error, no el último** (los de abajo suelen ser consecuencia), copia el mensaje exacto y búscalo aquí.

### Docker

| Mensaje | Causa y solución |
| --- | --- |
| `error during connect ... dockerDesktopLinuxEngine: The system cannot find the file specified` | Docker Desktop no está en marcha. Ábrelo y espera a que el icono esté "running" |
| `docker: command not found` | Docker no está instalado o falta en el `PATH`; reabre la terminal (capítulo 01) |
| `COPY failed: file not found in build context` | Ejecutaste `docker build` desde otra carpeta. El contexto es la **raíz** del repo: `docker build -f apps/api/Dockerfile -t api:local .` |
| `port is already allocated` | El puerto local está ocupado; usa otro: `-p 8081:8080` |
| El contenedor arranca y se detiene al instante | `docker logs <contenedor>` muestra el motivo |
| `unauthorized` / `denied` al `docker push` | Falta `az acr login --name <acr>` o el rol `AcrPush` |

### GitHub Actions

| Mensaje | Causa y solución |
| --- | --- |
| `Workflow file is invalid` / error de sintaxis YAML | Indentación (espacios, no tabs) o comillas. Pega el YAML en un validador o usa la extensión de GitHub Actions de VS Code |
| `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL` | Falta `permissions: id-token: write` (también en el workflow que llama a uno reutilizable) |
| `AADSTS70021: No matching federated identity record found` | El subject del token no coincide con una credencial federada; compara mayúsculas, environment y repo (capítulo 10) |
| `Context access might be invalid: vars.X` o variable vacía | La variable no existe en ese nivel (repositorio/environment) o se escribió distinto |
| Job "Waiting" para siempre | Espera aprobación del environment `prod`. Revisa *Review deployments* |
| `Resource not accessible by integration` | Faltan `permissions` (por ejemplo `pull-requests: write`) |
| El workflow no se dispara | `paths:` o `branches:` no coinciden con lo que cambiaste; o el archivo no está en la rama por defecto (algunos eventos solo leen la de master) |
| CI falla en `dotnet format --verify-no-changes` | Ejecuta `dotnet format Monorepo.slnx` en local y sube el resultado |

### Terraform

| Mensaje | Causa y solución |
| --- | --- |
| `Error acquiring the state lock` | Otra ejecución activa o bloqueo colgado; `terraform force-unlock <ID>` solo si estás seguro |
| `Backend initialization required` | Cambió el backend: `terraform init` de nuevo |
| `No value for required variable subscription_id` | Falta `$env:TF_VAR_subscription_id` |
| `AuthorizationPermissionMismatch` en `init` | Falta `Storage Blob Data Contributor` sobre la cuenta del state, o el rol no se propagó (2-5 min) |
| `Unsupported argument` / `Unsupported block type` | Versión del provider distinta; `terraform init -upgrade` y revisa la documentación del recurso |
| `The registry name ... is not available` | Nombre global ocupado; cambia `project` en `terraform.tfvars` |
| `Terraform fmt` falla en CI | `terraform fmt -recursive infra` y commit |
| Un plan quiere **destruir** algo que no esperabas | Detente. Revisa si cambiaste un argumento que fuerza reemplazo (`-/+`); revierte o entiende el motivo antes de aplicar |

### Azure

| Mensaje / síntoma | Causa y solución |
| --- | --- |
| `AuthorizationFailed ... does not have authorization to perform action` | Falta el rol necesario en ese ámbito (`az role assignment list --assignee ...`); los roles tardan unos minutos en propagarse |
| `MissingSubscriptionRegistration` / `not registered to use namespace 'Microsoft.Web'` | `az provider register --namespace Microsoft.Web` (y `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`, `Microsoft.Insights`) |
| `Operation cannot be completed without additional quota` | Tu suscripción no tiene cuota de ese SKU/región; prueba otra región o SKU |
| La web devuelve `503` o "Application Error" | El contenedor no arranca o la imagen no existe. Ver "Logs de la web app" abajo |
| `ImagePullFailure` / `unauthorized` al bajar la imagen | La identidad de la app no tiene `AcrPull` sobre el ACR, o la imagen/tag no existe (`az acr repository show-tags`) |
| `/health` devuelve 404 | Despliegas una imagen anterior a T2 (sin `/health`), o la ruta cambió |
| `Please run 'az login'` | La sesión caducó: `az login` |

**Logs de la web app** (muy útil para 503):

```powershell
az webapp log config --name <APP_NAME> --resource-group <RG> --docker-container-logging filesystem
az webapp log tail   --name <APP_NAME> --resource-group <RG>
```

También en el portal: la web app → **Log stream** y **Diagnose and solve problems**.

## 5. Checklist final

Marca cada punto cuando lo hayas **visto funcionar**:

- [ ] `dotnet build` y `dotnet test` pasan en local (cap. 03-04)
- [ ] `docker build` y `docker run` sirven `/health` en local (cap. 05)
- [ ] CI está en verde en un PR y la rama `master` exige ese check (cap. 06, 02)
- [ ] `terraform fmt -check` y `validate` pasan en dev y prod (cap. 07-09)
- [ ] `terraform apply` de dev creó los recursos y `terraform output` muestra la URL (cap. 09)
- [ ] La identidad OIDC existe, **sin** secretos de cliente (cap. 10)
- [ ] Variables de repositorio y environments `dev`/`prod` configurados; prod exige revisor (cap. 10)
- [ ] Un merge a master construyó la imagen, la desplegó en dev y el smoke test pasó (cap. 11)
- [ ] Un PR que toca `infra/` mostró el plan como comentario (cap. 11)
- [ ] Hiciste un rollback a un SHA anterior (cap. 11)
- [ ] Tienes un presupuesto con alertas (este capítulo)
- [ ] Sabes destruir todo y verificar que no queda nada (este capítulo)

## 6. Ejercicios (de menor a mayor dificultad)

Cada uno indica el **resultado esperado**. Hazlos en una rama y con PR.

1. **Local de punta a punta.** Ejecuta `dotnet test`, construye la imagen y llama a `/health` con `curl`. *Esperado:* 7 tests en verde y respuesta `{"status":"Healthy"}`.
2. **Nuevo endpoint con TDD.** Añade `GET /version` que devuelva `{"version":"1.0.0"}`: escribe primero el test en `tests/Api.Tests` y comprueba que falla (RED), implementa (GREEN) y abre un PR. *Esperado:* CI en verde y el test nuevo en el log.
3. **Aprobación en prod.** Crea el environment `prod` con *Required reviewers*, define `ENABLE_PROD=true` solo si ya tienes prod aplicado, y lanza *Deploy* a mano. *Esperado:* el job de prod queda en "Waiting" hasta que lo apruebas. Si tu plan de GitHub no permite revisores en repos privados, anota la limitación y comprueba qué cambia (prod se desplegaría sin pausa).
4. **Romper y arreglar CI.** Deja un `using` sin usar o rompe el formato a propósito. *Esperado:* `Check formatting` falla en rojo; lo corriges con `dotnet format` y vuelve a verde.
5. **Cambio de infraestructura por PR.** En `infra/envs/dev/terraform.tfvars` cambia `log_retention_days` de 30 a 60 y abre un PR. *Esperado:* un comentario de plan con `~` (cambio en sitio) y `Plan: 0 to add, 1 to change, 0 to destroy`; al fusionar, `terraform-apply` lo aplica.
6. **Rollback.** Despliega dos versiones distintas, anota el SHA de la primera y vuelve a ella con *Run workflow*. *Esperado:* `/health` sigue OK y `az webapp config container show` (o el portal) muestra el tag antiguo.
7. **Separar identidades (avanzado).** Diseña (y si te animas implementa) una identidad `sp-devopslab-github-plan` con solo rol `Reader` en los grupos de recursos y `Storage Blob Data Contributor` en el state, solo con la credencial `pull_request`, y úsala en `terraform-plan.yml`. *Esperado:* el plan sigue funcionando y un PR malicioso ya no podría modificar prod. Pista: `terraform plan` necesita leer, no escribir.
8. **Drift.** Cambia a mano en el portal una etiqueta (tag) del grupo de recursos de dev y ejecuta `terraform plan`. *Esperado:* el plan muestra `~` para restaurar el valor del código. Decide: ¿aplicas o cambias el código?
9. **Presupuesto.** Crea un presupuesto de 5 USD con alertas al 50 % y 100 %. *Esperado:* ves el presupuesto en *Cost Management → Budgets* con tu correo en las notificaciones.
10. **Cierre completo.** Ejecuta la sección 2 entera. *Esperado:* `az group list` no muestra ningún `rg-devopslab-*` y `az ad app list --display-name sp-devopslab-github` devuelve una lista vacía.
