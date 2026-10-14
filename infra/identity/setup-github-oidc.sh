#!/usr/bin/env bash
# Crea en Azure la "identidad" que GitHub Actions usara para desplegar, SIN contrasenas.
# Equivalente en bash de setup-github-oidc.ps1 (el .ps1 es el de referencia en Windows).
# Explicacion completa, concepto a concepto: docs/10-azure-identidad-oidc.md
#
# Que crea:
#   1. Un "app registration" en Microsoft Entra ID (la "ficha" de la aplicacion).
#   2. Un "service principal" (la cuenta de servicio que realmente recibe permisos).
#   3. "Federated credentials": reglas que dicen "confio en tokens firmados por GitHub
#      SOLO si vienen de este repositorio y de este contexto (environment, PR, rama)".
#   4. Role assignments: lo que esa identidad puede hacer en Azure (minimo privilegio).
#
# Requisitos antes de ejecutarlo (en este orden):
#   - az login  &&  az account set --subscription "<SUBSCRIPTION_ID>"
#   - Haber ejecutado infra/bootstrap (cuenta de Storage del state).
#   - Haber hecho el primer "terraform apply" de dev (y de prod si lo usaras): este
#     script da permisos sobre el grupo de recursos y el ACR, que deben EXISTIR ya.
#   - Tu usuario necesita poder crear apps en Entra ID (rol "Application Administrator"
#     o similar) y poder asignar roles (Owner o User Access Administrator) en la suscripcion.
#
# Uso:    ./setup-github-oidc.sh <owner/repo> <cuenta-storage-del-state> [proyecto]
# Ejemplo: ./setup-github-oidc.sh mi-usuario/api-monorepo-azure stdevopslabtfa1b2 devopslab
#
# Es idempotente: si algo ya existe, lo salta (puedes volver a ejecutarlo).
# Solo para un ambiente:  ENVIRONMENTS="dev" ./setup-github-oidc.sh ...

# -e: parar al primer error. -u: error si usas una variable no definida.
# -o pipefail: un fallo dentro de una tuberia cuenta como fallo.
set -euo pipefail

# En Git Bash (Windows) evita que "/subscriptions/..." se convierta en una ruta de Windows.
export MSYS_NO_PATHCONV=1

REPO="${1:?Falta el repositorio con formato propietario/nombre, por ejemplo mi-usuario/api-monorepo-azure}"
STATE_ACCOUNT="${2:?Falta el nombre de la cuenta de Storage del state (la imprimio el bootstrap)}"
PROJECT="${3:-devopslab}"
ENVIRONMENTS="${ENVIRONMENTS:-dev prod}"

APP_NAME="sp-${PROJECT}-github"
STATE_RG="rg-${PROJECT}-tfstate"
ISSUER="https://token.actions.githubusercontent.com" # quien firma los tokens de GitHub
AUDIENCE="api://AzureADTokenExchange"                 # para quien van dirigidos (Entra ID)

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
TENANT_ID="$(az account show --query tenantId --output tsv)"

# ---------------------------------------------------------------------------
# 1) App registration (si no existe ya una con ese nombre).
# ---------------------------------------------------------------------------
APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv)"
if [ -z "$APP_ID" ]; then
  APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)"
  echo "App registration creada: $APP_NAME"
else
  echo "App registration ya existia: $APP_NAME"
fi
# APP_ID es el "client id". NO es un secreto.

# ---------------------------------------------------------------------------
# 2) Service principal asociado a la app.
# ---------------------------------------------------------------------------
SP_OBJECT_ID="$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" --output tsv)"
if [ -z "$SP_OBJECT_ID" ]; then
  SP_OBJECT_ID="$(az ad sp create --id "$APP_ID" --query id --output tsv)"
  echo "Service principal creado."
fi

# ---------------------------------------------------------------------------
# 3) Credenciales federadas: una por cada "contexto" desde el que GitHub puede entrar.
#    El "subject" es el texto EXACTO que GitHub pone dentro de su token.
# ---------------------------------------------------------------------------
add_credential() {
  local name="$1" subject="$2"
  local existing
  existing="$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'].name" --output tsv)"
  if [ -n "$existing" ]; then
    echo "Credencial ya existia: $name"
    return
  fi
  az ad app federated-credential create --id "$APP_ID" --parameters \
    "{\"name\":\"$name\",\"issuer\":\"$ISSUER\",\"subject\":\"$subject\",\"audiences\":[\"$AUDIENCE\"]}" \
    --output none
  echo "Credencial creada: $name  ->  $subject"
}

# Jobs que declaran "environment: dev" / "environment: prod" en el workflow.
for ENV_NAME in $ENVIRONMENTS; do
  add_credential "github-env-${ENV_NAME}" "repo:${REPO}:environment:${ENV_NAME}"
done
# Jobs que corren en un pull request (terraform plan) y en la rama master.
add_credential "github-pull-request" "repo:${REPO}:pull_request"
add_credential "github-branch-master" "repo:${REPO}:ref:refs/heads/master"

# ---------------------------------------------------------------------------
# 4) Roles. Funcion que asigna un rol solo si todavia no esta asignado.
# ---------------------------------------------------------------------------
assign_role() {
  local role="$1" scope="$2"
  local existing
  existing="$(az role assignment list --assignee "$SP_OBJECT_ID" --role "$role" --scope "$scope" --query "[0].id" --output tsv)"
  if [ -n "$existing" ]; then
    echo "Rol ya asignado: $role"
    return
  fi
  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope" \
    --output none
  echo "Rol asignado: $role  en  $scope"
}

# 4a) Leer/escribir el state de Terraform (cuenta de Storage, ambito = solo esa cuenta).
STATE_ACCOUNT_ID="$(az storage account show --name "$STATE_ACCOUNT" --resource-group "$STATE_RG" --query id --output tsv)"
assign_role "Storage Blob Data Contributor" "$STATE_ACCOUNT_ID"

for ENV_NAME in $ENVIRONMENTS; do
  RG="rg-${PROJECT}-${ENV_NAME}"
  RG_ID="$(az group show --name "$RG" --query id --output tsv)"
  ACR_ID="$(az acr list --resource-group "$RG" --query "[0].id" --output tsv)"

  # 4b) Contributor: crear/modificar recursos dentro del grupo de recursos del ambiente.
  assign_role "Contributor" "$RG_ID"
  # 4c) Contributor NO puede crear role assignments, y nuestro Terraform crea uno
  #     (AcrPull de la web app). Este rol lo permite, solo dentro de ese grupo.
  assign_role "Role Based Access Control Administrator" "$RG_ID"
  # 4d) AcrPush: subir (y descargar) imagenes en el registro de ese ambiente.
  assign_role "AcrPush" "$ACR_ID"
done

echo
echo "Listo. Guarda estos valores como VARIABLES (no secretos) en GitHub:"
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  TFSTATE_RESOURCE_GROUP  = $STATE_RG"
echo "  TFSTATE_STORAGE_ACCOUNT = $STATE_ACCOUNT"
echo "Siguiente paso: docs/10-azure-identidad-oidc.md, seccion 'Configurar GitHub'."
