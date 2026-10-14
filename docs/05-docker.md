# 05 - Docker: empaquetar la API en un contenedor

Este capítulo explica qué es Docker, por qué lo usamos y cómo construir y ejecutar la API dentro de un contenedor. No necesitas saber nada previo. Los términos nuevos están en el [glosario](00-glosario.md).

## El problema que resuelve

"En mi máquina funciona." Cada ordenador tiene una versión distinta de .NET, de librerías y de configuración. Un contenedor empaqueta la aplicación **junto con todo lo que necesita** para ejecutarse, de modo que se comporta igual en tu portátil, en CI y en Azure.

## Imagen vs contenedor

| Concepto | Qué es | Analogía |
| --- | --- | --- |
| **Imagen** (image) | Plantilla inmutable de solo lectura con la app y sus dependencias | La receta ya cocinada, congelada |
| **Contenedor** (container) | Proceso en ejecución creado a partir de una imagen | Un plato servido a partir de esa receta |

De una misma imagen puedes crear muchos contenedores. Si borras un contenedor, la imagen sigue intacta.

Un contenedor **no es una máquina virtual**: no lleva su propio sistema operativo completo, comparte el núcleo (kernel) del anfitrión. Por eso arranca en segundos y pesa poco.

## Capas (layers) y caché

Una imagen se construye como una pila de **capas**. Cada instrucción del `Dockerfile` (`COPY`, `RUN`...) crea una capa. Docker guarda cada capa en una caché: si una instrucción y todo lo anterior no ha cambiado desde el último build, la reutiliza en vez de ejecutarla de nuevo.

Consecuencia práctica: **ordena las instrucciones de lo que cambia menos a lo que cambia más**. Los paquetes NuGet cambian poco; el código cambia constantemente. Por eso restauramos paquetes *antes* de copiar el código.

## Multi-stage build

Para compilar .NET hace falta el **SDK** (compilador, ~800 MB). Para ejecutar solo hace falta el **runtime** (~200 MB). Un build *multi-stage* usa varias etapas (`FROM`) en un mismo Dockerfile:

1. Etapa `build`: imagen del SDK, compila y publica.
2. Etapa `final`: imagen del runtime, recibe solo el resultado publicado.

La imagen final no contiene el SDK ni el código fuente: es más pequeña, más rápida de descargar y tiene menos superficie de ataque.

## Archivos de este capítulo

| Archivo | Para qué sirve |
| --- | --- |
| `apps/api/Dockerfile` | Instrucciones para construir la imagen |
| `.dockerignore` (raíz) | Lista de lo que no se envía a Docker al construir |

### Contexto de build

El comando `docker build ... .` termina con un punto: es el **contexto de build**, la carpeta cuyo contenido Docker puede ver. Usamos la **raíz del repositorio** (no `apps/api`) porque el build necesita `global.json`, `Directory.Build.props` y `.editorconfig`, que están en la raíz. Las rutas de `COPY` son relativas a ese contexto.

## El Dockerfile, línea a línea

```dockerfile
# syntax=docker/dockerfile:1
```
Directiva especial: indica qué versión de la sintaxis de Dockerfile usar. Es una buena práctica incluirla.

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
```
Empieza una etapa nueva llamada `build` a partir de la imagen oficial del SDK de .NET 10 (alojada en el registry de Microsoft, `mcr.microsoft.com`). El `10.0` es el **tag**.

```dockerfile
WORKDIR /src
```
Fija la carpeta de trabajo dentro de la imagen; las instrucciones siguientes se ejecutan ahí. Si no existe, se crea.

```dockerfile
COPY global.json Directory.Build.props .editorconfig ./
COPY apps/api/Api.csproj apps/api/
```
Copia solo la configuración del repositorio y el archivo de proyecto. Todavía no copiamos código fuente (ver "capas y caché").

```dockerfile
RUN dotnet restore apps/api/Api.csproj
```
Descarga los paquetes NuGet. Esta capa solo se rehace si cambia alguno de los archivos copiados justo antes.

```dockerfile
COPY apps/api/ apps/api/
```
Ahora sí copia el código fuente. Un cambio en un `.cs` invalida la caché a partir de aquí, pero el `restore` anterior se conserva.

```dockerfile
RUN dotnet publish apps/api/Api.csproj -c Release --no-restore -o /app/publish
```
Compila en Release y deja el resultado en `/app/publish`. `--no-restore` evita repetir el restore.

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
```
Segunda etapa, basada en la imagen ligera de runtime de ASP.NET. Lo anterior (SDK, código) queda fuera.

```dockerfile
WORKDIR /app
COPY --from=build /app/publish .
```
`--from=build` copia archivos desde la etapa `build`, no desde tu disco. Solo se lleva la app publicada.

```dockerfile
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
```
`ENV` define una variable de entorno: ASP.NET Core escuchará en el puerto 8080. `EXPOSE` es solo documentación; **no publica** el puerto (eso lo hace `-p` al ejecutar). Usamos un puerto superior a 1024 porque un usuario sin privilegios no puede abrir puertos bajos.

```dockerfile
USER app
```
Ejecuta el proceso como el usuario `app`, que ya existe en las imágenes oficiales de .NET y **no es root**. Si alguien explotase un fallo de la API, tendría muchos menos permisos dentro del contenedor.

```dockerfile
ENTRYPOINT ["dotnet", "Api.dll"]
```
Comando que se ejecuta al arrancar el contenedor. La forma con corchetes (*exec form*) lanza el proceso directamente, de modo que recibe las señales de parada correctamente.

## `.dockerignore`

Funciona como `.gitignore`, pero para el contexto de build. Excluimos `.git`, `bin/`, `obj/`, tests, docs y secretos. Ventajas: el build es más rápido, la caché no se invalida por archivos irrelevantes y no se cuelan secretos (`.env`) en la imagen.

## Requisito previo

Docker Desktop instalado y **en ejecución** (ver [01 - Requisitos y setup](01-requisitos-y-setup.md)). Comprueba:

```bash
docker version
```
Debe mostrar dos secciones: `Client` y `Server`. Si solo aparece `Client` y un error, Docker Desktop no está arrancado.

## Construir la imagen

Desde la raíz del repositorio:

```bash
docker build -f apps/api/Dockerfile -t api:local .
```

- `-f apps/api/Dockerfile`: ruta del Dockerfile.
- `-t api:local`: nombre (`api`) y tag (`local`) de la imagen.
- `.`: contexto de build (la raíz).

Salida esperada (resumida): líneas `[build 3/7] RUN dotnet restore ...` y al final `naming to docker.io/library/api:local`. La primera vez tarda varios minutos (descarga las imágenes base); las siguientes, segundos gracias a la caché. Comprueba que existe:

```bash
docker images api
```

## Ejecutar el contenedor

```bash
docker run -d --name api -p 8080:8080 api:local
```

- `-d`: en segundo plano (*detached*).
- `--name api`: nombre del contenedor, para referirnos a él luego.
- `-p 8080:8080`: **publica** el puerto. Formato `puerto_de_tu_PC:puerto_del_contenedor`. Sin esto, la API sería inalcanzable desde fuera.

Prueba el endpoint de salud:

```bash
curl http://localhost:8080/health
```
Salida esperada:
```json
{"status":"Healthy"}
```

Y `curl http://localhost:8080/user` devuelve la lista de usuarios. Swagger **no** estará disponible: solo se habilita en `Development` y el contenedor corre en `Production` por defecto.

## Comandos del día a día

| Comando | Qué hace |
| --- | --- |
| `docker ps` | Lista contenedores en ejecución (`-a` incluye los parados) |
| `docker logs api` | Muestra la salida del contenedor (`-f` para seguirla en vivo) |
| `docker stop api` | Para el contenedor de forma ordenada |
| `docker rm api` | Borra el contenedor (ya parado) |
| `docker images` | Lista imágenes locales |
| `docker rmi api:local` | Borra la imagen |
| `docker exec -it api sh` | Abre una shell dentro del contenedor (la imagen es mínima y puede no traer herramientas como `curl`) |

Limpieza al terminar:

```bash
docker stop api
docker rm api
```

## Errores comunes

| Síntoma | Causa y solución |
| --- | --- |
| `failed to connect to the docker API ... dockerDesktopLinuxEngine` | Docker Desktop no está arrancado. Ábrelo y espera a que diga "Engine running" |
| `port is already allocated` / `address already in use` | Otro proceso usa el 8080. Cambia a `-p 9090:8080` y llama a `localhost:9090` |
| `COPY failed: file not found in build context` | Ejecutaste el build desde otra carpeta, o el archivo está en `.dockerignore`. Ejecuta desde la raíz |
| `curl: (52) Empty reply` o `connection refused` | La app aún arranca (espera 2-3 s) o olvidaste `-p`. Revisa `docker logs api` |
| `Conflict. The container name "/api" is already in use` | Ya existe un contenedor `api`. Haz `docker rm -f api` |
| El build tarda siempre lo mismo | Algo antes del `restore` cambia en cada build; revisa el orden de los `COPY` |

## Qué viene después

En el siguiente capítulo, GitHub Actions construirá y comprobará el proyecto automáticamente en cada cambio. Más adelante la imagen se subirá a ACR (el registry de Azure) y se desplegará.
