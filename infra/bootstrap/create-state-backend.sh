#!/usr/bin/env bash
# Crea en Azure el almacenamiento donde Terraform guardara su "state".
# Equivalente en bash de create-state-backend.ps1 (leelo: ahi cada paso esta
# explicado con mas detalle). NO lo ejecutes sin entender cada comando.
#
# Requiere antes:  az login  &&  az account set --subscription "<SUBSCRIPTION_ID>"
# Uso:             ./create-state-backend.sh <sufijo-corto> [proyecto] [region]
#                  ./create-state-backend.sh a1b2 devopslab westeurope

# -e: parar al primer error. -u: error si usas una variable no definida.
# -o pipefail: un fallo dentro de una tuberia cuenta como fallo.
set -euo pipefail

SUFFIX="${1:?Falta el sufijo corto (3-6 letras/numeros), por ejemplo a1b2}"
PROJECT="${2:-devopslab}"
LOCATION="${3:-westeurope}"

RESOURCE_GROUP="rg-${PROJECT}-tfstate"
STORAGE_ACCOUNT="st${PROJECT}tf${SUFFIX}" # 3-24 caracteres, solo minusculas y numeros
CONTAINER="tfstate"

# 1) Grupo de recursos que contendra el almacenamiento del state.
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# 2) Cuenta de almacenamiento barata (LRS), con TLS 1.2 y sin acceso publico.
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# 3) Versionado y papelera (7 dias) para poder recuperar un state danado.
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 7

# 4) Rol "Storage Blob Data Contributor" para tu usuario (Terraform usa tu
#    identidad de Entra ID, no claves de la cuenta).
USER_ID="$(az ad signed-in-user show --query id --output tsv)"
ACCOUNT_ID="$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id --output tsv)"
az role assignment create \
  --assignee-object-id "$USER_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$ACCOUNT_ID"

# 5) Contenedor para los ficheros .tfstate (el rol puede tardar 1-2 min en
#    propagarse: si falla, espera y reintenta).
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo
echo "Listo. Usa estos valores en 'terraform init':"
echo "  -backend-config=\"resource_group_name=${RESOURCE_GROUP}\""
echo "  -backend-config=\"storage_account_name=${STORAGE_ACCOUNT}\""
echo "  -backend-config=\"container_name=${CONTAINER}\""
