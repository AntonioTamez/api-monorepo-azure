# Variables de entrada del ambiente. Los valores concretos estan en
# terraform.tfvars (los no secretos) o en variables de entorno TF_VAR_<nombre>.

# Sin "default": Terraform exige un valor. Se pasa con $env:TF_VAR_subscription_id.
variable "subscription_id" {
  type        = string
  description = "ID de la suscripcion de Azure donde se despliega."
}

variable "project" {
  type        = string
  description = "Nombre corto del proyecto: minusculas y numeros, 3-12 caracteres."

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.project))
    error_message = "project debe tener 3-12 caracteres, solo letras minusculas y numeros."
  }
}

variable "environment" {
  type        = string
  description = "Nombre del ambiente: dev o prod."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser dev o prod."
  }
}

variable "location" {
  type        = string
  description = "Region de Azure."
  default     = "westeurope"
}

variable "acr_sku" {
  type        = string
  description = "Nivel del Container Registry: Basic, Standard o Premium."
}

variable "app_service_sku" {
  type        = string
  description = "Tamano del App Service Plan (B1, P1v3...)."
}

variable "always_on" {
  type        = bool
  description = "Mantener la app siempre cargada."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Dias de retencion de logs."
  default     = 30
}

variable "docker_image_name" {
  type        = string
  description = "Imagen a desplegar (sin servidor), por ejemplo api:latest."
  default     = "api:latest"
}
