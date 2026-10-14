# 00 - Glosario

Este glosario explica, desde cero, los términos que aparecen en el laboratorio. No hace falta memorizarlo: úsalo como diccionario cuando un capítulo mencione una palabra que no conoces.

Los términos están agrupados por tema.

## Ideas generales

### DevOps
Forma de trabajar en la que quienes escriben el software (Dev) y quienes lo ponen en funcionamiento (Ops) colaboran y automatizan el camino que va desde el código hasta los usuarios. El objetivo es entregar cambios pequeños, frecuentes y seguros.

### Repositorio (repo)
Carpeta de proyecto controlada por Git, que guarda todo el historial de cambios. Este repositorio es un monorepo: un único repositorio con varios proyectos dentro (la API, los tests, la infraestructura).

### Entorno (environment)
Copia independiente de la aplicación y de su infraestructura. En este laboratorio habrá dos: `dev` (para probar sin riesgo) y `prod` (el que usarían los usuarios reales).

## Integración y entrega continuas

### CI (Integración Continua)
Práctica que consiste en que, cada vez que alguien sube un cambio, un sistema automático compila el código y ejecuta los tests. Sirve para detectar errores en minutos y no en semanas.

### CD (Entrega o Despliegue Continuo)
Continuación de CI: si los controles automáticos pasan, el sistema entrega el cambio al entorno de destino (por ejemplo, lo publica en Azure) sin pasos manuales repetitivos. "Entrega" suele implicar una aprobación humana final; "despliegue" lo hace todo automáticamente.

### Pipeline
Secuencia automática de pasos (compilar, probar, empaquetar, desplegar). Es el concepto general; cada herramienta lo implementa a su manera.

### GitHub Actions
Servicio de GitHub que ejecuta automatizaciones cuando ocurre algo en el repositorio (un push, un pull request, una hora programada).

### Workflow
En GitHub Actions, un pipeline concreto descrito en un archivo YAML dentro de `.github/workflows/`. Un repositorio puede tener varios workflows.

### Job
Conjunto de pasos de un workflow que se ejecutan juntos en una misma máquina. Los jobs pueden correr en paralelo o esperarse entre sí.

### Step (paso)
Una acción individual dentro de un job: ejecutar un comando o usar una acción reutilizable (`uses`).

### Runner
La máquina (virtual) que ejecuta un job. GitHub ofrece runners propios (por ejemplo `ubuntu-latest`) o puedes aportar los tuyos.

### Trigger (disparador)
Evento que inicia un workflow, como `push`, `pull_request` o `workflow_dispatch` (ejecución manual).

### Artifact (artefacto)
Archivo o conjunto de archivos producido por un pipeline y que se conserva para usarlo después: un ejecutable, un informe de cobertura, un paquete. No confundir con "image" (ver más abajo).

### Secret
Valor sensible (contraseña, token) guardado cifrado en GitHub y disponible para los workflows sin que aparezca en el código. En este laboratorio se evitarán casi por completo gracias a OIDC.

### Branch protection (protección de rama)
Reglas de GitHub que impiden, por ejemplo, subir directamente a `master` o fusionar un pull request si no pasaron los checks de CI.

## Contenedores

### Container (contenedor)
Proceso aislado que lleva dentro la aplicación y todo lo que necesita para funcionar (runtime, librerías). Se comporta igual en tu portátil, en CI y en la nube. Es más ligero que una máquina virtual porque comparte el núcleo del sistema operativo.

### Image (imagen)
Plantilla inmutable a partir de la cual se crean contenedores. La imagen es "la receta ya cocinada"; el contenedor es "un plato servido". Se construye con un `Dockerfile`.

### Dockerfile
Archivo de texto con las instrucciones para construir una imagen.

### Docker
Herramienta más extendida para construir imágenes y ejecutar contenedores.

### Registry (registro de imágenes)
Almacén donde se guardan y descargan imágenes de contenedor (como un "GitHub para imágenes"). Docker Hub es público; en este laboratorio usaremos ACR.

### Tag
Etiqueta que identifica una versión de una imagen (por ejemplo `api:1.0.3` o `api:a1b2c3d`).

### ACR (Azure Container Registry)
El registry privado de Azure. Ahí se subirán las imágenes de la API.

## Infraestructura como código

### IaC (Infraestructura como Código)
Describir la infraestructura (servidores, redes, bases de datos) en archivos de texto versionados en lugar de crearla a mano en un portal web. Es repetible, revisable y reversible.

### Terraform
Herramienta de IaC de HashiCorp. Lees archivos `.tf` que describen el estado deseado y Terraform calcula qué hay que crear, cambiar o borrar para llegar a él.

### Provider (proveedor)
Plugin de Terraform que sabe hablar con una plataforma concreta. Para Azure se usa el provider `azurerm`.

### Resource (recurso)
Bloque de Terraform que declara una pieza de infraestructura (por ejemplo, un grupo de recursos o un App Service).

### Variable y output
Una variable es un parámetro de entrada de Terraform; un output es un valor que se expone al terminar (por ejemplo, la URL de la aplicación).

### Module (módulo)
Carpeta de Terraform reutilizable que agrupa recursos relacionados y se invoca con parámetros, como una función.

### Terraform state (estado)
Archivo donde Terraform anota qué recursos reales creó y con qué identificadores. Sin él no sabría qué le pertenece. Contiene datos sensibles, así que no se sube a Git: se guarda en un "backend remoto" (aquí, una cuenta de Azure Storage) que además bloquea el estado (locking) para que dos personas no lo modifiquen a la vez.

### Plan y apply
`terraform plan` muestra los cambios que se harían sin ejecutarlos. `terraform apply` los ejecuta.

### Drift
Diferencia entre lo que describe el código y lo que realmente existe, normalmente por cambios manuales en el portal.

## Azure

### Cloud (nube)
Servidores y servicios de otra empresa que alquilas por uso. Azure es la nube de Microsoft.

### Tenant
Instancia de Microsoft Entra ID (antes Azure Active Directory) que representa a una organización: contiene sus usuarios, grupos y aplicaciones. Tiene un identificador único (Tenant ID).

### Subscription (suscripción)
Contenedor de facturación y de límites dentro de un tenant. Todo recurso de Azure pertenece a una suscripción, y es a ella a quien se cobra.

### Resource group (grupo de recursos)
Carpeta lógica dentro de una suscripción que agrupa recursos relacionados. Borrar el grupo borra todo lo que contiene, lo que facilita limpiar el laboratorio.

### Region (región)
Ubicación geográfica de los centros de datos (por ejemplo `westeurope`).

### Microsoft Entra ID
Servicio de identidades de Microsoft: usuarios, aplicaciones y permisos.

### Service principal
Identidad "de robot" de una aplicación o automatización dentro de Entra ID. Es lo que usará GitHub Actions para actuar sobre Azure, en lugar de tu usuario personal.

### Managed identity (identidad administrada)
Service principal cuyas credenciales gestiona Azure por ti; nunca ves ni rotas una contraseña. Se usará para que el App Service descargue imágenes de ACR.

### RBAC (Control de acceso basado en roles)
Sistema de permisos de Azure: asignas un rol (por ejemplo `Reader`, `Contributor`, `AcrPull`) a una identidad sobre un ámbito (suscripción, grupo de recursos o recurso).

### Role assignment (asignación de rol)
Registro que une identidad + rol + ámbito.

### OIDC (OpenID Connect)
Protocolo que permite a GitHub demostrar su identidad a Azure con un token de corta duración, sin guardar contraseñas ni secretos en GitHub. Azure confía en tokens emitidos para un repositorio y rama concretos mediante una "federated credential".

### Federated credential
Configuración en Entra ID que dice: "confío en tokens de GitHub que provengan de este repositorio y este entorno".

### App Service
Servicio de Azure para alojar aplicaciones web sin administrar servidores. Se compone de un App Service Plan (el "tamaño" de la máquina) y una Web App (tu aplicación).

### Log Analytics workspace
Almacén central de logs y métricas en Azure que se puede consultar con un lenguaje de consultas (KQL).

### Application Insights
Servicio de monitorización de aplicaciones (peticiones, errores, rendimiento) que guarda sus datos en un Log Analytics workspace.

### Azure CLI (`az`)
Herramienta de línea de comandos para gestionar Azure.

## Calidad y .NET

### SDK y runtime de .NET
El SDK contiene las herramientas para compilar (`dotnet build`); el runtime solo lo necesario para ejecutar. En producción basta con el runtime.

### Minimal API
Estilo de ASP.NET Core para definir endpoints con muy poco código, como `app.MapGet("/user", ...)`.

### Endpoint
Dirección de la API a la que se hacen peticiones (por ejemplo `GET /health`).

### Health check
Endpoint pensado para que sistemas automáticos pregunten "¿estás vivo?". Devuelve 200 si todo va bien.

### Test unitario y de integración
El unitario prueba una pieza aislada. El de integración levanta la aplicación (en memoria) y la prueba como lo haría un cliente HTTP.

### Cobertura (coverage)
Porcentaje del código ejecutado por los tests.

### Linter y analyzer
Herramientas que revisan el código sin ejecutarlo para detectar errores y problemas de estilo.

### Conventional Commits
Convención para escribir mensajes de commit (`feat:`, `fix:`, `docs:`...) que se detalla en `docs/02-git-y-ramas.md`.
