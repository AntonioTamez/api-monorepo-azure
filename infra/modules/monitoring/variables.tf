variable "log_analytics_name" {
  type        = string
  description = "Nombre del Log Analytics workspace."
}

variable "application_insights_name" {
  type        = string
  description = "Nombre del recurso Application Insights."
}

variable "resource_group_name" {
  type        = string
  description = "Grupo de recursos donde se crean ambos recursos."
}

variable "location" {
  type        = string
  description = "Region de Azure."
}

variable "retention_in_days" {
  type        = number
  description = "Dias de retencion de logs (minimo 30 con PerGB2018)."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican a los recursos."
  default     = {}
}
