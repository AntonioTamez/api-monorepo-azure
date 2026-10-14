output "workspace_id" {
  description = "ID del Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

# sensitive = true: Terraform oculta el valor en la consola ("(sensitive value)").
# La cadena de conexion permite enviar telemetria a tu Application Insights, asi
# que se trata como secreto. OJO: sigue guardada en texto plano en el state.
output "connection_string" {
  description = "Cadena de conexion de Application Insights."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
