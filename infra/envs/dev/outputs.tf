# Outputs: se imprimen al terminar "apply" y se consultan con "terraform output".
# Los usaran los pipelines de CD (capitulos siguientes).

output "resource_group_name" {
  description = "Grupo de recursos del ambiente."
  value       = module.resource_group.name
}

output "acr_name" {
  description = "Nombre del Container Registry."
  value       = module.acr.name
}

output "acr_login_server" {
  description = "Servidor del ACR para docker login / docker push."
  value       = module.acr.login_server
}

output "app_name" {
  description = "Nombre de la Web App."
  value       = module.app_service.app_name
}

output "app_url" {
  description = "URL publica de la API."
  value       = "https://${module.app_service.default_hostname}"
}

# Tenant ID leido con el data source de main.tf; se necesitara para OIDC.
output "tenant_id" {
  description = "ID del tenant de Microsoft Entra ID."
  value       = data.azurerm_client_config.current.tenant_id
}

# sensitive = true: se oculta en consola; se ve con "terraform output -raw".
output "application_insights_connection_string" {
  description = "Cadena de conexion de Application Insights."
  value       = module.monitoring.connection_string
  sensitive   = true
}
