# Valores NO secretos del ambiente dev. Terraform carga automaticamente
# cualquier fichero llamado terraform.tfvars.
#
# NO pongas aqui subscription_id: pasalo con $env:TF_VAR_subscription_id.
# NUNCA pongas contrasenas ni claves en un .tfvars versionado.

# Cambia "devopslab" si quieres: es el prefijo de todos los nombres.
project     = "devopslab"
environment = "dev"
location    = "westeurope"

# DEV: lo mas barato que sirve para contenedores Linux.
# B1 ~ 12-13 USD/mes. (F1 gratuito existe pero tiene muchas limitaciones y no
# es adecuado para contenedores personalizados.)
acr_sku            = "Basic"
app_service_sku    = "B1"
always_on          = false
log_retention_days = 30
