# Una "variable" es un parametro de entrada del modulo. Quien llama al modulo
# le da un valor. "type" restringe el tipo; "description" documenta su uso.

variable "name" {
  type        = string
  description = "Nombre del grupo de recursos en Azure."
}

variable "location" {
  type        = string
  description = "Region de Azure donde se crea el grupo (por ejemplo westeurope)."
}

# map(string) = diccionario de texto a texto. "default" hace la variable
# opcional: si nadie la define, vale {} (sin etiquetas).
variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican al recurso."
  default     = {}
}
