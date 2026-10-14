# 01 - Requisitos y preparación del equipo

Antes de empezar necesitas instalar unas herramientas. Este capítulo explica qué hace cada una, cómo instalarla en Windows y cómo comprobar que funciona. Los términos desconocidos están en [el glosario](00-glosario.md).

## Qué vas a instalar

| Herramienta | Para qué sirve | Comando de verificación |
| --- | --- | --- |
| .NET SDK 10 | Compilar, probar y ejecutar la API | `dotnet --version` |
| Git | Controlar versiones del código | `git --version` |
| Docker Desktop | Construir y ejecutar contenedores | `docker --version` |
| Azure CLI | Gestionar Azure desde la terminal | `az --version` |
| Terraform | Crear infraestructura desde código | `terraform version` |
| GitHub CLI | Usar GitHub desde la terminal | `gh --version` |

También necesitas:

- Una cuenta de GitHub.
- Una suscripción de Azure (una cuenta gratuita sirve). Hasta el capítulo de Azure no se crea nada de pago.

## Terminal

Usa PowerShell o Windows Terminal. Cada vez que instales algo, cierra y vuelve a abrir la terminal: así se carga la variable `PATH` actualizada (la lista de carpetas donde Windows busca programas).

## Instalación con winget

`winget` es el gestor de paquetes de Windows 11. Comprueba que lo tienes:

```powershell
winget --version
```

Instala las herramientas (cada comando puede pedir confirmación de permisos de administrador):

```powershell
winget install --id Microsoft.DotNet.SDK.10 -e
winget install --id Git.Git -e
winget install --id Docker.DockerDesktop -e
winget install --id Microsoft.AzureCLI -e
winget install --id Hashicorp.Terraform -e
winget install --id GitHub.cli -e
```

Notas por herramienta:

- **Docker Desktop**: al terminar hay que reiniciar el equipo y aceptar los términos de licencia. Necesita WSL 2 (Windows Subsystem for Linux); el instalador lo ofrece activar. Abre la aplicación y espera a que el icono indique "Engine running".
- **.NET**: si ya tienes otra versión, no pasa nada; pueden convivir. El archivo `global.json` del repositorio (se añade en el capítulo 03) fija la versión que usa este proyecto.

## Verificar versiones

Ejecuta todo esto en una terminal nueva:

```powershell
dotnet --version
git --version
docker --version
az --version
terraform version
gh --version
```

Salida esperada (los números pueden ser más recientes):

```text
10.0.xxx
git version 2.xx.x.windows.x
Docker version 2x.x.x, build xxxxxxx
azure-cli 2.xx.x
Terraform v1.x.x
gh version 2.xx.x
```

Verifica además que Docker puede ejecutar contenedores:

```powershell
docker run --rm hello-world
```

Debe imprimir "Hello from Docker!". Si dice que no puede conectar con el daemon, Docker Desktop no está arrancado.

## Configurar Git

Git necesita saber quién eres para firmar tus commits:

```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tu-correo@ejemplo.com"
```

Comprueba lo guardado con `git config --global --list`.

## Iniciar sesión en GitHub

```powershell
gh auth login
```

Elige `GitHub.com`, protocolo `HTTPS` y autenticación por navegador. Verifica con:

```powershell
gh auth status
```

## Iniciar sesión en Azure

```powershell
az login
```

Se abre el navegador para que inicies sesión. Al terminar, la terminal muestra las suscripciones disponibles. Comprueba la activa:

```powershell
az account show --query "{nombre:name, id:id, tenant:tenantId}" -o table
```

Si tienes varias suscripciones y la activa no es la correcta:

```powershell
az account list -o table
az account set --subscription "<ID o nombre de la suscripción>"
```

Aquí aparecen dos conceptos del glosario: **tenant** y **subscription**. Apunta ambos identificadores; los necesitarás más adelante.

## Obtener el código

```powershell
git clone <URL-del-repositorio>
cd api-monorepo-azure
dotnet build Monorepo.slnx
```

El último comando debe terminar con `Build succeeded` y `0 Error(s)`.

## Errores comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `'dotnet' no se reconoce como un comando` | La terminal se abrió antes de instalar | Cierra y abre la terminal; si persiste, reinicia sesión |
| `The command could not be loaded... SDK 10 not found` | Falta el SDK 10 o `global.json` pide una versión que no tienes | Ejecuta `dotnet --list-sdks` e instala el SDK 10 |
| `error during connect` o `Cannot connect to the Docker daemon` | Docker Desktop no está en ejecución | Abre Docker Desktop y espera a que arranque |
| Docker pide activar WSL 2 o virtualización | Virtualización desactivada en la BIOS o WSL ausente | Ejecuta `wsl --install` como administrador y reinicia |
| `az login` no abre el navegador | Entorno sin navegador | Usa `az login --use-device-code` |
| `AADSTS...` al hacer `az login` | Cuenta sin suscripción o política de la organización | Prueba con una cuenta personal gratuita |
| `winget` no encuentra un paquete | Nombre de paquete cambiado | Busca con `winget search <nombre>` |
