# Valores NO secretos del ambiente prod. Terraform carga automaticamente
# cualquier fichero llamado terraform.tfvars.
#
# NO pongas aqui subscription_id: pasalo con $env:TF_VAR_subscription_id.
# NUNCA pongas contrasenas ni claves en un .tfvars versionado.

project     = "devopslab"
environment = "prod"
location    = "westeurope"

# PROD: mas capacidad y mas retencion que dev, y por tanto MAS COSTO.
# P1v3 ~ 100-120 USD/mes. Para un laboratorio, destruye prod en cuanto termines
# (terraform destroy) o no lo apliques: aprender solo requiere hacer "plan".
acr_sku            = "Standard"
app_service_sku    = "P1v3"
always_on          = true
log_retention_days = 90
