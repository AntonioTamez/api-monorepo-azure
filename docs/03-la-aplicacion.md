# 03 - La aplicación

Este capítulo describe la API que se va a probar, empaquetar y desplegar durante el laboratorio, y los archivos de configuración que mantienen el código ordenado y reproducible. Los términos nuevos están en el [glosario](00-glosario.md).

## Qué es la aplicación

Es una **API web** hecha con ASP.NET Core (.NET 10) en estilo *minimal API*. Una API web es un programa que escucha peticiones HTTP y devuelve datos, normalmente en formato JSON. No tiene pantalla: otros programas (o tú con `curl`) le hacen preguntas.

Estructura relevante:

```text
apps/api/
├── Program.cs              # Punto de entrada: configura y arranca la aplicación
├── Users/                  # Endpoint GET /user y su modelo de respuesta
├── Health/                 # Endpoint GET /health
├── Api.http                # Peticiones de ejemplo para probar desde el editor
└── Api.csproj              # Definición del proyecto .NET
```

## Endpoints

| Método | Ruta | Respuesta |
| --- | --- | --- |
| GET | `/user` | Lista de usuarios de ejemplo (datos fijos en el código) |
| GET | `/health` | `200 OK` con `{"status":"Healthy"}` |
| GET | `/swagger` | Documentación interactiva (solo en Development) |

### Por qué existe `/health`

Un *health check* es un endpoint que responde "estoy vivo". Lo usarán más adelante:

- Docker (para saber si el contenedor funciona).
- Azure App Service (para decidir si reinicia la aplicación).
- Los workflows de despliegue (un *smoke test*: tras desplegar, se llama a `/health` para confirmar que todo arrancó).

Debe ser barato y no depender de nada externo, por eso devuelve un valor fijo.

## Ejecutar la aplicación

Desde la raíz del repositorio:

```powershell
dotnet run --project apps/api
```

Salida esperada (el puerto puede variar):

```text
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5251
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
```

En otra terminal:

```powershell
curl http://localhost:5251/health
```

Respuesta esperada:

```json
{"status":"Healthy"}
```

Para detener la aplicación, pulsa `Ctrl+C` en la terminal donde corre.

## Swagger solo en desarrollo

Swagger genera una página (`/swagger`) que describe y permite probar todos los endpoints. Es muy útil mientras desarrollas, pero en un entorno real expone información sobre la API que no hace falta publicar. Por eso `Program.cs` solo lo activa si el entorno es `Development`.

ASP.NET Core decide el entorno con la variable `ASPNETCORE_ENVIRONMENT`:

- `dotnet run` usa el perfil de `launchSettings.json`, que fija `Development`.
- En un contenedor o en Azure el valor por defecto es `Production`, así que `/swagger` devolverá 404. Es el comportamiento deseado.

Para comprobarlo:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Production"
dotnet run --project apps/api --no-launch-profile --urls http://localhost:5251
# En otra terminal: curl -i http://localhost:5251/swagger  -> 404
```

Recuerda borrar la variable después con `Remove-Item Env:ASPNETCORE_ENVIRONMENT`.

## Archivos de configuración del repositorio

### `global.json`

Fija la versión del SDK de .NET que se usa en el repositorio:

```json
{ "sdk": { "version": "10.0.100", "rollForward": "latestFeature" } }
```

- `version`: versión mínima requerida.
- `rollForward: latestFeature`: permite usar una versión más reciente de la misma línea 10.0 (por ejemplo 10.0.401), pero nunca saltar a la 11.

Para qué sirve: tu portátil, tus compañeros y el servidor de CI compilan con el mismo SDK, evitando el clásico "en mi máquina funciona".

### `Directory.Build.props`

MSBuild (el motor de compilación de .NET) lee este archivo automáticamente para **todos** los proyectos de las carpetas inferiores. Así la configuración común no se repite en cada `.csproj`:

- `Nullable`: el compilador avisa cuando algo puede ser `null`, evitando muchos errores en tiempo de ejecución.
- `TreatWarningsAsErrors`: un aviso rompe la compilación. Así los problemas no se acumulan; en CI es un control de calidad gratuito.
- `AnalysisLevel` = `latest-recommended`: activa las reglas de análisis de código recomendadas por Microsoft.
- `EnforceCodeStyleInBuild`: aplica en la compilación las reglas de estilo de `.editorconfig`.

### `.editorconfig`

Define el estilo de formato (sangría, codificación UTF-8, salto de línea final, reglas de C#). Los editores modernos lo leen solos, y `dotnet format` lo usará en CI para comprobar el formato.

### `.gitignore`

Lista lo que Git no debe guardar: carpetas generadas (`bin/`, `obj/`), resultados de tests, archivos de entorno con secretos (`.env`) y, preparando capítulos futuros, el estado de Terraform (`*.tfstate`). Nunca se debe subir un secreto: una vez en el historial de Git es difícil de eliminar y debe considerarse comprometido.

### `Api.http`

Archivo de peticiones de ejemplo para Visual Studio, Rider y la extensión REST Client de VS Code. Contiene ahora las peticiones a `/health` y `/user` (antes apuntaba a un endpoint de plantilla, `/weatherforecast`, que no existe).

## Compilar

```powershell
dotnet build Monorepo.slnx
```

Salida esperada al final:

```text
Compilación correcta.
    0 Advertencia(s)
    0 Errores
```

(En un sistema en inglés: `Build succeeded.`)

## Errores comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `MSB3027 ... The process cannot access the file 'Api.exe'` | La API sigue ejecutándose y bloquea el archivo | Deténla con `Ctrl+C` o cierra el proceso `Api` desde el Administrador de tareas |
| `error CS8618` / `CS86xx` (nullability) | Con `TreatWarningsAsErrors`, un aviso de nulos rompe la compilación | Inicializa la propiedad o decláralo como `string?` si puede ser nulo |
| `A compatible .NET SDK was not found` | `global.json` pide una versión que no tienes | Instala el SDK 10 (ver capítulo 01) |
| `/swagger` devuelve 404 | El entorno no es Development | Es lo esperado fuera de desarrollo; usa `dotnet run` normal |
