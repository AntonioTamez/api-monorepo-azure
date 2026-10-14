output "id" {
  description = "ID del ACR. Se usa como ambito (scope) del rol AcrPull."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Nombre del ACR."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Servidor del registro (<name>.azurecr.io), prefijo de las imagenes Docker."
  value       = azurerm_container_registry.this.login_server
}
