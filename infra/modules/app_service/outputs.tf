output "app_name" {
  description = "Nombre de la Web App."
  value       = azurerm_linux_web_app.this.name
}

output "default_hostname" {
  description = "Nombre DNS publico de la app (<app_name>.azurewebsites.net)."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "principal_id" {
  description = "ID de la identidad administrada de la app."
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}
