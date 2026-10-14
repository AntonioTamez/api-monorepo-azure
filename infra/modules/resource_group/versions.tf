# ---------------------------------------------------------------------------
# versions.tf - requisitos de versiones del modulo
# ---------------------------------------------------------------------------
# El bloque "terraform" no crea nada: solo declara con que versiones de
# Terraform y de providers es compatible este codigo.
# Un modulo NUNCA configura el provider (eso lo hace el ambiente que lo llama);
# solo declara que provider necesita en "required_providers".
terraform {
  # Version minima de la herramienta terraform (el binario) que acepta el modulo.
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      # De donde se descarga el plugin: registry.terraform.io/hashicorp/azurerm
      source = "hashicorp/azurerm"

      # "~> 4.0" significa ">= 4.0 y < 5.0": acepta mejoras menores, no saltos
      # de version mayor que podrian romper el codigo.
      version = "~> 4.0"
    }
  }
}
