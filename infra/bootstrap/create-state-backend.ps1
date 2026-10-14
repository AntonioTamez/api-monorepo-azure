<#
.SYNOPSIS
  Crea en Azure el almacenamiento donde Terraform guardara su "state".

.DESCRIPTION
  Problema del huevo y la gallina: Terraform guarda su state en una cuenta de
  Azure Storage, pero esa cuenta tiene que existir ANTES de usar Terraform.
  Por eso la creamos una sola vez a mano con Azure CLI (az), en este script.

  NO lo ejecutes sin entender cada comando. Requiere haber hecho antes:
      az login
      az account set --subscription "<SUBSCRIPTION_ID>"

.EXAMPLE
  ./create-state-backend.ps1 -Project devopslab -Suffix a1b2
#>
param(
  # Prefijo del proyecto: letras minusculas y numeros.
  [string]$Project = "devopslab",

  # Sufijo corto para que el nombre de la cuenta sea unico en todo Azure.
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{3,6}$')]
  [string]$Suffix,

  [string]$Location = "westeurope"
)

# Detener el script ante el primer error (en vez de seguir y dejar cosas a medias).
$ErrorActionPreference = "Stop"

# Nombres derivados. Una cuenta de Storage: 3-24 caracteres, solo minusculas y numeros.
$ResourceGroup  = "rg-$Project-tfstate"
$StorageAccount = "st${Project}tf${Suffix}"
$Container      = "tfstate"

Write-Host "Resource group:  $ResourceGroup"
Write-Host "Storage account: $StorageAccount"
Write-Host "Container:       $Container"

# 1) Grupo de recursos: la "carpeta" que contendra el almacenamiento del state.
az group create --name $ResourceGroup --location $Location

# 2) Cuenta de almacenamiento.
#    --sku Standard_LRS              : replicacion local, la opcion mas barata.
#    --kind StorageV2                : tipo de cuenta moderno, soporta blobs.
#    --min-tls-version TLS1_2        : rechaza conexiones con cifrado antiguo.
#    --allow-blob-public-access false: nadie puede leer el state sin autenticarse.
az storage account create `
  --name $StorageAccount `
  --resource-group $ResourceGroup `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false

# 3) Versionado y papelera de los blobs: si el state se corrompe o se borra por
#    error, se puede recuperar una version anterior (7 dias).
az storage account blob-service-properties update `
  --account-name $StorageAccount `
  --resource-group $ResourceGroup `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 7

# 4) Permiso para TI: Terraform se autentica con tu identidad de Entra ID
#    (use_azuread_auth = true en backend.tf), asi que necesitas el rol
#    "Storage Blob Data Contributor" sobre la cuenta. Sin el, init falla con 403.
$UserId    = az ad signed-in-user show --query id --output tsv
$AccountId = az storage account show --name $StorageAccount --resource-group $ResourceGroup --query id --output tsv
az role assignment create `
  --assignee-object-id $UserId `
  --assignee-principal-type User `
  --role "Storage Blob Data Contributor" `
  --scope $AccountId

# 5) Contenedor (carpeta de blobs) donde viviran los ficheros .tfstate.
#    --auth-mode login: usa tu identidad (no claves de la cuenta).
#    El rol del paso 4 puede tardar 1-2 minutos en propagarse: si falla, reintenta.
az storage container create `
  --name $Container `
  --account-name $StorageAccount `
  --auth-mode login

Write-Host ""
Write-Host "Listo. Usa estos valores en 'terraform init':"
Write-Host "  -backend-config=`"resource_group_name=$ResourceGroup`""
Write-Host "  -backend-config=`"storage_account_name=$StorageAccount`""
Write-Host "  -backend-config=`"container_name=$Container`""
