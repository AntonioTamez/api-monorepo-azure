<#
.SYNOPSIS
Crea en Azure la "identidad" que GitHub Actions usara para desplegar, SIN contrasenas.

.DESCRIPTION
Que crea:
  1. Un "app registration" en Microsoft Entra ID (la "ficha" de la aplicacion).
  2. Un "service principal" (la cuenta de servicio que realmente recibe permisos).
  3. "Federated credentials": reglas que dicen "confio en tokens firmados por GitHub
     SOLO si vienen de este repositorio y de este contexto (environment, PR, rama)".
  4. Role assignments: lo que esa identidad puede hacer en Azure (minimo privilegio).

Requisitos antes de ejecutarlo (en este orden):
  - az login ; az account set --subscription "<SUBSCRIPTION_ID>"
  - Haber ejecutado infra/bootstrap (cuenta de Storage del state).
  - Haber hecho el primer "terraform apply" de dev (y de prod si lo usaras): este
    script da permisos sobre el grupo de recursos y el ACR, que deben EXISTIR ya.
  - Tu usuario necesita poder crear apps en Entra ID (rol "Application Administrator"
    o similar) y asignar roles (Owner o User Access Administrator) en la suscripcion.

Es idempotente: si algo ya existe, lo salta (puedes volver a ejecutarlo).
Explicacion completa, concepto a concepto: docs/10-azure-identidad-oidc.md

.EXAMPLE
./infra/identity/setup-github-oidc.ps1 -Repository mi-usuario/api-monorepo-azure -StateAccount stdevopslabtfa1b2

.EXAMPLE
./infra/identity/setup-github-oidc.ps1 -Repository mi-usuario/api-monorepo-azure -StateAccount stdevopslabtfa1b2 -Environments dev
#>
param(
    # Repositorio de GitHub con formato propietario/nombre.
    [Parameter(Mandatory = $true)] [string] $Repository,
    # Cuenta de Storage del state (la imprimio el script de bootstrap).
    [Parameter(Mandatory = $true)] [string] $StateAccount,
    [string] $Project = "devopslab",
    # Ambientes que ya existen en Azure (su grupo de recursos y su ACR).
    [string[]] $Environments = @("dev", "prod")
)

# Parar al primer error de PowerShell. (Los comandos externos como az se comprueban
# con la funcion Invoke-Az de mas abajo, porque PowerShell no para solo con ellos.)
$ErrorActionPreference = "Stop"

$AppName  = "sp-$Project-github"
$StateRg  = "rg-$Project-tfstate"
$Issuer   = "https://token.actions.githubusercontent.com" # quien firma los tokens de GitHub
$Audience = "api://AzureADTokenExchange"                  # para quien van dirigidos (Entra ID)

# Ejecuta az y detiene el script si devuelve un codigo de error. Devuelve su salida.
function Invoke-Az {
    $output = & az @args
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') fallo (codigo $LASTEXITCODE)" }
    return $output
}

$SubscriptionId = Invoke-Az account show --query id --output tsv
$TenantId       = Invoke-Az account show --query tenantId --output tsv

# ---------------------------------------------------------------------------
# 1) App registration (si no existe ya una con ese nombre).
# ---------------------------------------------------------------------------
$AppId = Invoke-Az ad app list --display-name $AppName --query "[0].appId" --output tsv
if (-not $AppId) {
    $AppId = Invoke-Az ad app create --display-name $AppName --query appId --output tsv
    Write-Host "App registration creada: $AppName"
} else {
    Write-Host "App registration ya existia: $AppName"
}
# $AppId es el "client id". NO es un secreto.

# ---------------------------------------------------------------------------
# 2) Service principal asociado a la app.
# ---------------------------------------------------------------------------
$SpObjectId = Invoke-Az ad sp list --filter "appId eq '$AppId'" --query "[0].id" --output tsv
if (-not $SpObjectId) {
    $SpObjectId = Invoke-Az ad sp create --id $AppId --query id --output tsv
    Write-Host "Service principal creado."
}

# ---------------------------------------------------------------------------
# 3) Credenciales federadas: una por cada "contexto" desde el que GitHub puede entrar.
#    El "subject" es el texto EXACTO que GitHub pone dentro de su token.
# ---------------------------------------------------------------------------
function Add-Credential([string] $Name, [string] $Subject) {
    $existing = Invoke-Az ad app federated-credential list --id $AppId --query "[?name=='$Name'].name" --output tsv
    if ($existing) {
        Write-Host "Credencial ya existia: $Name"
        return
    }
    # Escribimos el JSON en un fichero temporal: pasar JSON por la linea de comandos
    # de PowerShell es una fuente clasica de errores de comillas.
    $file = New-TemporaryFile
    @{
        name      = $Name
        issuer    = $Issuer
        subject   = $Subject
        audiences = @($Audience)
    } | ConvertTo-Json | Set-Content -Path $file -Encoding utf8
    try {
        Invoke-Az ad app federated-credential create --id $AppId --parameters "@$($file.FullName)" --output none | Out-Null
    } finally {
        Remove-Item $file -Force
    }
    Write-Host "Credencial creada: $Name  ->  $Subject"
}

# Jobs que declaran "environment: dev" / "environment: prod" en el workflow.
foreach ($envName in $Environments) {
    Add-Credential "github-env-$envName" "repo:${Repository}:environment:$envName"
}
# Jobs que corren en un pull request (terraform plan) y en la rama master.
Add-Credential "github-pull-request" "repo:${Repository}:pull_request"
Add-Credential "github-branch-master" "repo:${Repository}:ref:refs/heads/master"

# ---------------------------------------------------------------------------
# 4) Roles. Funcion que asigna un rol solo si todavia no esta asignado.
# ---------------------------------------------------------------------------
function Add-Role([string] $Role, [string] $Scope) {
    $existing = Invoke-Az role assignment list --assignee $SpObjectId --role $Role --scope $Scope --query "[0].id" --output tsv
    if ($existing) {
        Write-Host "Rol ya asignado: $Role"
        return
    }
    Invoke-Az role assignment create `
        --assignee-object-id $SpObjectId `
        --assignee-principal-type ServicePrincipal `
        --role $Role `
        --scope $Scope `
        --output none | Out-Null
    Write-Host "Rol asignado: $Role  en  $Scope"
}

# 4a) Leer/escribir el state de Terraform (cuenta de Storage, ambito = solo esa cuenta).
$StateAccountId = Invoke-Az storage account show --name $StateAccount --resource-group $StateRg --query id --output tsv
Add-Role "Storage Blob Data Contributor" $StateAccountId

foreach ($envName in $Environments) {
    $rg    = "rg-$Project-$envName"
    $rgId  = Invoke-Az group show --name $rg --query id --output tsv
    $acrId = Invoke-Az acr list --resource-group $rg --query "[0].id" --output tsv

    # 4b) Contributor: crear/modificar recursos dentro del grupo de recursos del ambiente.
    Add-Role "Contributor" $rgId
    # 4c) Contributor NO puede crear role assignments, y nuestro Terraform crea uno
    #     (AcrPull de la web app). Este rol lo permite, solo dentro de ese grupo.
    Add-Role "Role Based Access Control Administrator" $rgId
    # 4d) AcrPush: subir (y descargar) imagenes en el registro de ese ambiente.
    Add-Role "AcrPush" $acrId
}

Write-Host ""
Write-Host "Listo. Guarda estos valores como VARIABLES (no secretos) en GitHub:"
Write-Host "  AZURE_CLIENT_ID         = $AppId"
Write-Host "  AZURE_TENANT_ID         = $TenantId"
Write-Host "  AZURE_SUBSCRIPTION_ID   = $SubscriptionId"
Write-Host "  TFSTATE_RESOURCE_GROUP  = $StateRg"
Write-Host "  TFSTATE_STORAGE_ACCOUNT = $StateAccount"
Write-Host "Siguiente paso: docs/10-azure-identidad-oidc.md, seccion 'Configurar GitHub'."
