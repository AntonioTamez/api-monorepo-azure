variable "name" {
  type        = string
  description = "Nombre del ACR: unico en Azure, 5-50 caracteres alfanumericos en minuscula."

  # "validation" rechaza valores invalidos en el plan, antes de hablar con Azure.
  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.name))
    error_message = "El nombre del ACR debe tener 5-50 caracteres, solo letras minusculas y numeros."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Grupo de recursos donde se crea el ACR."
}

variable "location" {
  type        = string
  description = "Region de Azure."
}

variable "sku" {
  type        = string
  description = "Nivel del ACR: Basic, Standard o Premium."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku debe ser Basic, Standard o Premium."
  }
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican al recurso."
  default     = {}
}
