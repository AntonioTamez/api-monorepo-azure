# syntax=docker/dockerfile:1
#
# Dockerfile multi-stage para la API.
# El "contexto de build" es la RAIZ del repositorio (el "." del comando docker build),
# por eso las rutas de COPY empiezan en la raiz: apps/api/..., global.json, etc.
#
# Comando (desde la raiz del repo):
#   docker build -f apps/api/Dockerfile -t api:local .

# ---------------------------------------------------------------------------
# Etapa 1: build. Usa la imagen del SDK (grande, con compilador).
# Esta etapa se descarta al final: nada de ella viaja a la imagen final.
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

# Carpeta de trabajo dentro de la imagen. Se crea si no existe.
WORKDIR /src

# 1) Copiamos SOLO lo necesario para restaurar paquetes NuGet.
#    Mientras estos archivos no cambien, Docker reutiliza la capa de cache
#    del restore y no vuelve a descargar paquetes en cada build.
COPY global.json Directory.Build.props .editorconfig ./
COPY apps/api/Api.csproj apps/api/

# Descarga los paquetes NuGet declarados en Api.csproj.
RUN dotnet restore apps/api/Api.csproj

# 2) Ahora si copiamos el codigo fuente. Cambiar un .cs invalida la cache
#    desde aqui, pero el restore anterior sigue cacheado.
COPY apps/api/ apps/api/

# Publica la app en Release. --no-restore reutiliza el restore de arriba.
# -o /app/publish deja el resultado en una carpeta conocida.
RUN dotnet publish apps/api/Api.csproj -c Release --no-restore -o /app/publish

# ---------------------------------------------------------------------------
# Etapa 2: runtime. Usa la imagen de ASP.NET (pequena, solo para ejecutar).
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

# Copia SOLO el resultado publicado desde la etapa "build".
COPY --from=build /app/publish .

# Puerto HTTP en el que escucha ASP.NET Core dentro del contenedor.
# 8080 (> 1024) permite no ser root. Es el valor por defecto de la imagen,
# lo declaramos explicito para que se vea.
ENV ASPNETCORE_HTTP_PORTS=8080

# EXPOSE es solo documentacion: no publica el puerto. Eso lo hace "docker run -p".
EXPOSE 8080

# La imagen aspnet ya trae un usuario sin privilegios llamado "app" (UID 1654).
# Ejecutar como no-root limita el dano si alguien explota la aplicacion.
USER app

# Proceso que arranca el contenedor.
ENTRYPOINT ["dotnet", "Api.dll"]
