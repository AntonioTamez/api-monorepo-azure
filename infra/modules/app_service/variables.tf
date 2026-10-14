variable "plan_name" {
  type        = string
  description = "Nombre del App Service Plan."
}

# El nombre forma parte de la URL publica <app_name>.azurewebsites.net, por eso
# debe ser unico en todo Azure.
variable "app_name" {
  type        = string
  description = "Nombre de la Web App (unico en Azure)."
}

variable "resource_group_name" {
  type        = string
  description = "Grupo de recursos donde se crean los recursos."
}

variable "location" {
  type        = string
  description = "Region de Azure."
}

variable "sku_name" {
  type        = string
  description = "Tamano del plan (por ejemplo B1, P1v3)."
  default     = "B1"
}

variable "always_on" {
  type        = bool
  description = "Mantener la app siempre cargada (no disponible en Free)."
  default     = false
}

variable "acr_id" {
  type        = string
  description = "ID del ACR sobre el que la app tendra el rol AcrPull."
}

variable "acr_login_server" {
  type        = string
  description = "Servidor del ACR (<name>.azurecr.io)."
}

variable "docker_image_name" {
  type        = string
  description = "Imagen con tag que se despliega, sin servidor (por ejemplo api:latest)."
  default     = "api:latest"
}

# sensitive = true en una variable oculta su valor en la salida de plan/apply.
variable "application_insights_connection_string" {
  type        = string
  description = "Cadena de conexion de Application Insights."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican a los recursos."
  default     = {}
}
