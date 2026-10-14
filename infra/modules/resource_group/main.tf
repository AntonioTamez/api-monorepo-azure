# ---------------------------------------------------------------------------
# Modulo resource_group
# ---------------------------------------------------------------------------
# Un "resource group" (grupo de recursos) es la carpeta de Azure donde viven
# todos los recursos de un ambiente. Borrar el grupo borra todo su contenido.

# Sintaxis: resource "<TIPO>" "<NOMBRE_LOCAL>" { ... }
#  - "azurerm_resource_group" es el tipo (lo define el provider azurerm).
#  - "this" es un nombre local: solo sirve para referirnos a este recurso desde
#    otros bloques (azurerm_resource_group.this). No es el nombre en Azure.
resource "azurerm_resource_group" "this" {
  # Nombre real que tendra el grupo en Azure. Viene de una variable.
  name = var.name

  # Region de Azure donde se crea (por ejemplo "westeurope").
  location = var.location

  # Etiquetas (clave/valor) para identificar, filtrar y asignar costos.
  tags = var.tags
}
