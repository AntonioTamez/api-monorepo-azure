# Un "output" es un valor que el modulo devuelve a quien lo llama.
# Se usa asi desde fuera: module.resource_group.name

output "name" {
  description = "Nombre del grupo de recursos."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Region del grupo de recursos."
  value       = azurerm_resource_group.this.location
}

output "id" {
  description = "ID completo del grupo en Azure (/subscriptions/.../resourceGroups/...)."
  value       = azurerm_resource_group.this.id
}
