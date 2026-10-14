# 06 - GitHub Actions: integración continua (CI)

Este capítulo explica cómo funciona el workflow `.github/workflows/ci.yml`, que comprueba automáticamente cada cambio del proyecto. No necesitas experiencia previa. Los términos están en el [glosario](00-glosario.md).

## Qué problema resuelve

Sin automatización, cada persona debe acordarse de compilar, formatear y ejecutar los tests antes de subir código. Alguien se olvidará. **CI (Integración Continua)** hace esas comprobaciones por ti, en una máquina limpia, en cada cambio. Si algo falla, lo ves en minutos y el cambio no se puede fusionar.

## Conceptos

| Concepto | Qué es |
| --- | --- |
| **Workflow** | Un proceso automatizado descrito en un archivo YAML dentro de `.github/workflows/` |
| **Trigger** (`on`) | El evento que lo inicia: `push`, `pull_request`, ejecución manual... |
| **Job** | Grupo de pasos que se ejecutan en una misma máquina. Aquí hay uno: `build-and-test` |
| **Step** | Cada paso del job: un comando (`run`) o una acción reutilizable (`uses`) |
| **Runner** | La máquina virtual que ejecuta el job. `ubuntu-latest` es un Linux que GitHub te presta |
| **Action** (`uses`) | Paso empaquetado y reutilizable escrito por otros, p. ej. `actions/checkout@v4` |
| **Artifact** | Archivos que el workflow guarda al terminar (aquí, el informe de cobertura) |

Jerarquía: un repositorio tiene workflows; un workflow tiene jobs; un job tiene steps. Cada ejecución del workflow se llama **run**.

Una máquina runner empieza **vacía** en cada ejecución: no tiene tu código, ni .NET configurado, ni caché. Por eso el primer paso descarga el código y el segundo instala .NET.

## YAML en un minuto

YAML es un formato de texto para datos. Reglas que necesitas:

- La **indentación con espacios** (nunca tabuladores) indica anidación. Un espacio de más rompe el archivo.
- `clave: valor` define un dato; `- elemento` define una lista.
- `#` inicia un comentario.
- `|` permite escribir un bloque de varias líneas (se usa para scripts); `>` une las líneas en una sola.

## El workflow, sección por sección

### Nombre y triggers

```yaml
name: CI
on:
  push:
    branches: [master]
  pull_request:
```
- `name`: cómo aparece en la pestaña **Actions**.
- `push` a `master`: se ejecuta cuando entra código en la rama principal.
- `pull_request`: se ejecuta cuando abres o actualizas un PR. Es el trigger más importante: valida el cambio **antes** de fusionarlo.

No usamos `push` para todas las ramas: duplicaría ejecuciones, porque una rama con PR ya se valida por `pull_request`.

### Permisos (mínimo privilegio)

```yaml
permissions:
  contents: read
```
Cada ejecución recibe un token temporal (`GITHUB_TOKEN`) con el que puede actuar sobre el repositorio. Por defecto puede tener permisos amplios. Aquí lo reducimos a **solo lectura**: si un paso o una acción de terceros se viera comprometido, no podría modificar tu repositorio. Regla: da a cada workflow solo lo que necesita y amplía cuando haga falta.

### Concurrencia

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
Si subes dos commits seguidos a la misma rama, la ejecución del primero ya no interesa. `group` identifica "la misma cosa" (workflow + rama) y `cancel-in-progress: true` cancela la anterior. Ahorra minutos y espera. `${{ ... }}` es una **expresión**: GitHub sustituye su valor al ejecutar.

### El job

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
```
`runs-on` elige el runner. `timeout-minutes` evita que un job colgado consuma tiempo hasta el límite por defecto (6 horas).

### Los pasos

1. **Checkout** (`actions/checkout@v4`): descarga el código en el runner.
2. **Setup .NET** (`actions/setup-dotnet@v4` con `global-json-file`): instala la versión del SDK declarada en `global.json`. Así CI y tu máquina usan la misma versión.
3. **Cache NuGet** (`actions/cache@v4`): guarda `~/.nuget/packages` entre ejecuciones. La `key` incluye un hash de los `.csproj`: si no cambian las dependencias, la caché se reutiliza y el restore es casi instantáneo; si cambian, se crea una nueva. `restore-keys` permite aprovechar una caché antigua parcial.
4. **Restore**: `dotnet restore` descarga dependencias.
5. **Check formatting**: `dotnet format Monorepo.slnx --verify-no-changes` falla si el código no respeta `.editorconfig`. No modifica nada, solo verifica. Si falla, ejecuta `dotnet format Monorepo.slnx` en local y sube el cambio.
6. **Build**: compila en `Release`. Por `Directory.Build.props`, los warnings cuentan como errores.
7. **Test**: `dotnet test` con `--collect:"XPlat Code Coverage"`, que usa `coverlet` para medir qué porcentaje del código ejecutan los tests y escribe un `coverage.cobertura.xml`.
8. **Upload coverage report** (`actions/upload-artifact@v4`): guarda ese informe como artefacto, descargable desde la página del run durante 7 días. `if: always()` lo sube incluso si los tests fallaron, que es cuando más útil es.
9. **Scan vulnerable packages**: `dotnet list package --vulnerable --include-transitive` consulta la base de vulnerabilidades de NuGet, incluidas las dependencias de tus dependencias (transitivas). El comando **no devuelve error por sí solo**, así que guardamos su salida y, si contiene el aviso "has the following vulnerable packages", emitimos `::error::` (una anotación visible en la interfaz) y `exit 1` para fallar el job.

### Por qué `@v4` y no `@main`

`uses: actions/checkout@v4` fija la acción a una versión mayor: recibes arreglos compatibles pero no cambios que rompan. Nunca uses `@main` ni `@latest`: el código de la acción podría cambiar sin avisar. (Una opción aún más estricta es fijar el hash completo del commit; Dependabot puede mantenerlo actualizado.)

## Dependabot

`.github/dependabot.yml` configura un bot de GitHub que, cada semana, abre pull requests cuando hay versiones nuevas de:

- paquetes **NuGet** (`nuget`),
- las **acciones** de los workflows (`github-actions`),
- las **imágenes base** del `Dockerfile` (`docker`, en `/apps/api`).

Cada PR de Dependabot pasa por el CI, así que sabrás si la actualización rompe algo antes de aceptarla.

## Plantilla de pull request

`.github/pull_request_template.md` rellena automáticamente la descripción de cada PR nuevo con preguntas y una checklist (qué cambia, cómo se probó, formato, tests). Es una ayuda para no olvidar pasos.

## Ver una ejecución

1. En GitHub abre la pestaña **Actions** del repositorio.
2. Elige el workflow **CI** y una ejecución (run). Verás el job y su icono: verde (éxito), rojo (fallo), amarillo (en curso), gris (cancelado).
3. Entra en el job: cada step aparece como una sección desplegable con su log.
4. Abajo de la página del run, sección **Artifacts**, está `coverage-report`.

En un pull request, los checks aparecen al final de la conversación, con enlace "Details" al run.

## Cómo leer un run fallido

1. Abre el job en rojo y busca el **primer step con una cruz roja**. Los siguientes suelen estar omitidos por consecuencia.
2. Despliega ese step y baja hasta las líneas `Error` (a menudo resaltadas en rojo) o `##[error]`.
3. Identifica el tipo de fallo:

| Step que falla | Causa habitual | Qué hacer |
| --- | --- | --- |
| Check formatting | Código sin formatear | `dotnet format Monorepo.slnx` en local, commit y push |
| Build | Error de compilación o warning (cuenta como error) | Reproduce con `dotnet build Monorepo.slnx -c Release` |
| Test | Un test falla | Reproduce con `dotnet test Monorepo.slnx`; el log indica qué test y por qué |
| Scan vulnerable packages | Un paquete tiene una vulnerabilidad | El log muestra el paquete y su gravedad; actualiza a la versión corregida |
| Setup .NET | `global.json` pide una versión inexistente | Revisa `global.json` |

4. **Reproduce siempre en local** los mismos comandos que ejecuta el workflow, en el mismo orden. Si falla en CI pero no en local, compara versiones del SDK y busca diferencias entre Windows y Linux (por ejemplo, mayúsculas/minúsculas en nombres de archivo).
5. Corrige, haz commit y push: el CI se vuelve a ejecutar solo. También puedes usar **Re-run jobs** si sospechas de un fallo puntual de la infraestructura.

Para más detalle de un step, activa **Enable debug logging** al reintentar un run, o consulta el log completo con el icono de engranaje > "View raw logs".

## Ejecutar los mismos comandos en local

Desde la raíz del repositorio:

```bash
dotnet restore Monorepo.slnx
dotnet format Monorepo.slnx --verify-no-changes
dotnet build Monorepo.slnx -c Release --no-restore
dotnet test Monorepo.slnx -c Release --no-build --collect:"XPlat Code Coverage" --results-directory ./TestResults
dotnet list Monorepo.slnx package --vulnerable --include-transitive
```
Salida esperada: sin diferencias de formato, `0 Errores`, `Superado: 7`, y "no tiene paquetes vulnerables" para cada proyecto. (El texto sale en tu idioma; en el runner está en inglés, por eso el workflow busca la frase en inglés.)

Si falla el build con archivos bloqueados, hay un `Api.exe` en ejecución: ciérralo.

## Checks obligatorios y protección de rama

Un workflow que falla no impide por sí solo fusionar. Para que sea obligatorio hay que configurar la protección de rama (concepto explicado en [02 - Git y ramas](02-git-y-ramas.md)):

1. Repositorio > **Settings** > **Branches** (o **Rules** > **Rulesets**).
2. **Add branch protection rule** para `master`.
3. Marca **Require a pull request before merging**.
4. Marca **Require status checks to pass before merging** y busca el check **Build and test** (el `name` del job). Solo aparece en el buscador después de haberse ejecutado al menos una vez en la última semana.
5. Marca **Require branches to be up to date before merging** (opcional, más estricto).
6. Guarda.

A partir de ahí, un PR con el CI en rojo no se puede fusionar.

> Las reglas de protección en repositorios privados pueden requerir un plan de GitHub de pago. En repositorios públicos son gratuitas.

## Errores comunes

| Síntoma | Causa y solución |
| --- | --- |
| El workflow no aparece en Actions | El archivo no está en `.github/workflows/` o no está en la rama por defecto/PR. Revisa la ruta |
| `Invalid workflow file` con número de línea | Error de YAML (indentación). Corrige la línea indicada |
| El check "Build and test" no se encuentra al configurar la rama | Aún no se ha ejecutado nunca; abre un PR de prueba |
| Pasa en local y falla en CI de formato | Fin de línea o editor distinto; ejecuta `dotnet format` y revisa `.editorconfig` |
| `Resource not accessible by integration` | El workflow necesita un permiso que `permissions` no concede; añade solo ese permiso |
| La caché no se reutiliza | La `key` cambió (cambió un `.csproj`); es normal la primera vez |
| Ejecuciones duplicadas | Mismo cambio dispara `push` y `pull_request`; en este workflow `push` solo aplica a `master` |

## Qué viene después

Este workflow solo **comprueba**. En capítulos posteriores se añadirán workflows que construyen la imagen Docker y despliegan en Azure (CD), reutilizando estos mismos conceptos.
