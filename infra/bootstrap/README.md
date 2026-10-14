# infra/bootstrap

Crea **una sola vez** el almacenamiento donde Terraform guardará su *state* (ver `docs/07-terraform-fundamentos.md`).

## Por qué existe esta carpeta

Terraform necesita un lugar donde guardar el state, y ese lugar (una cuenta de Azure Storage) tiene que existir **antes** de ejecutar Terraform. No se puede crear con el propio Terraform que lo va a usar (huevo y gallina), así que se crea con Azure CLI (`az`).

## Qué crea

| Recurso | Nombre de ejemplo | Para qué |
| --- | --- | --- |
| Resource group | `rg-devopslab-tfstate` | Carpeta que contiene el almacenamiento |
| Storage account | `stdevopslabtfa1b2` | Cuenta donde se guardan los ficheros |
| Blob container | `tfstate` | Carpeta dentro de la cuenta; ahí viven `dev.tfstate` y `prod.tfstate` |

Además activa versionado y papelera de borrado (para recuperar un state dañado) y te da el rol `Storage Blob Data Contributor` sobre la cuenta.

## Cómo usarlo (solo cuando tengas una suscripción de Azure)

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"

# PowerShell (Windows)
./infra/bootstrap/create-state-backend.ps1 -Suffix a1b2

# o bash (Git Bash, WSL, Linux, macOS)
./infra/bootstrap/create-state-backend.sh a1b2
```

`a1b2` es un sufijo corto inventado por ti: los nombres de cuentas de Storage son únicos en **todo Azure**; si el nombre ya existe, elige otro sufijo.

Al terminar, el script imprime los tres valores que pasarás a `terraform init -backend-config=...` (ver `docs/09-terraform-ambientes-y-comandos.md`).

## Costo y limpieza

Una cuenta `Standard_LRS` con un fichero de unos KB cuesta céntimos al mes. Para borrarlo todo al terminar el laboratorio (**después** de hacer `terraform destroy` en cada ambiente):

```powershell
az group delete --name rg-devopslab-tfstate --yes
```
