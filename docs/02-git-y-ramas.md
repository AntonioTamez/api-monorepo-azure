# 02 - Git, ramas y pull requests

En este capítulo aprenderás el flujo de trabajo con Git que se usa en todo el laboratorio. Es la base de CI/CD: los pipelines se activan por eventos de Git (un push, un pull request).

## Qué es Git y por qué importa

Git guarda el historial de un proyecto como una cadena de **commits**. Un commit es una fotografía del código con un mensaje que explica el cambio. Una **rama** (branch) es una línea de commits independiente: te permite trabajar en algo sin afectar a la rama principal.

GitHub es un servicio que aloja repositorios Git y añade colaboración: pull requests, revisiones y automatizaciones (Actions).

## Flujo de ramas del laboratorio

La rama principal se llama `master` y siempre debe estar en un estado que compila y pasa los tests. Nadie trabaja directamente en ella.

```text
master   o---o-----------o-----o   (siempre estable)
              \         /
feat/xyz       o---o---o          (tu trabajo, vía pull request)
```

Pasos:

1. Actualiza `master`:
   ```powershell
   git switch master
   git pull
   ```
2. Crea una rama para tu cambio:
   ```powershell
   git switch -c feat/nombre-corto
   ```
3. Edita, y guarda el trabajo en commits pequeños:
   ```powershell
   git status
   git add <archivos>
   git commit -m "feat: add health endpoint"
   ```
4. Sube la rama a GitHub:
   ```powershell
   git push -u origin feat/nombre-corto
   ```
5. Abre un pull request (ver más abajo), espera a que pasen los checks y pide revisión.
6. Cuando se apruebe, se fusiona (merge) en `master` y se borra la rama.

### Nombres de ramas

Usa un prefijo que indique el tipo de cambio, igual que en los commits:

| Prefijo | Uso |
| --- | --- |
| `feat/` | Nueva funcionalidad |
| `fix/` | Corrección de un error |
| `docs/` | Solo documentación |
| `chore/` | Mantenimiento (dependencias, configuración) |
| `ci/` | Cambios en pipelines |

## Conventional Commits

Es una convención para escribir mensajes de commit con una estructura fija:

```text
<tipo>(<ámbito opcional>): <descripción en imperativo>
```

Tipos habituales:

| Tipo | Significado |
| --- | --- |
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de error |
| `docs` | Documentación |
| `test` | Añadir o modificar tests |
| `refactor` | Cambio de código sin cambiar el comportamiento |
| `chore` | Tareas de mantenimiento |
| `ci` | Pipelines y automatizaciones |
| `build` | Sistema de compilación y dependencias |

Ejemplos:

```text
feat(api): add health endpoint
fix(api): return 404 when user does not exist
docs: add git workflow chapter
test(api): cover the /user endpoint
```

Por qué se usa: el historial queda legible, y las herramientas pueden generar versiones y changelogs automáticamente. Reglas prácticas: descripción corta (menos de 72 caracteres), en imperativo ("add", no "added") y un cambio lógico por commit.

Los mensajes de commit y el código de este repositorio están en inglés; la documentación, en español.

## Pull requests

Un **pull request** (PR) es una petición para fusionar tu rama en otra. Sirve para:

- Que otra persona revise el cambio.
- Que el sistema de CI ejecute compilación y tests sobre tu cambio antes de fusionarlo.
- Dejar un registro de por qué se hizo.

Crear uno desde la terminal:

```powershell
gh pr create --base master --title "feat: add health endpoint" --body "Explica qué cambia y por qué."
```

Buenas prácticas:

- Pequeño: idealmente menos de 400 líneas modificadas; así se revisa bien.
- Descripción clara: qué, por qué y cómo probarlo.
- Los checks de CI deben estar en verde antes de pedir revisión.

Tipos de fusión que ofrece GitHub:

| Tipo | Efecto |
| --- | --- |
| Merge commit | Conserva todos los commits y añade uno de fusión |
| Squash and merge | Junta todos los commits del PR en uno solo |
| Rebase and merge | Reaplica tus commits encima de `master` sin commit de fusión |

Para este laboratorio se recomienda `Squash and merge`, que mantiene el historial de `master` limpio.

## Protección de ramas (branch protection)

Es una configuración de GitHub que impide que `master` se rompa. Se activa en `Settings > Branches > Add branch protection rule` (o con *rulesets*) sobre `master`:

- **Require a pull request before merging**: prohíbe subir directamente.
- **Require approvals**: exige al menos una aprobación (si trabajas solo, puede dejarse en 0 o usar tu propio PR).
- **Require status checks to pass**: obliga a que el workflow de CI esté en verde. Se podrá activar cuando exista el workflow (capítulo de GitHub Actions), porque el check debe haberse ejecutado al menos una vez para aparecer en la lista.
- **Require branches to be up to date**: el PR debe incluir los últimos cambios de `master`.
- **Do not allow bypassing**: ni siquiera los administradores se saltan las reglas.

Esto es la pieza que conecta Git con CI: sin checks obligatorios, el pipeline informa pero no protege.

## Errores comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `fatal: not a git repository` | Estás fuera de la carpeta del repositorio | `cd` al repositorio |
| `error: failed to push some refs` | Tu rama local está desactualizada | `git pull --rebase` y vuelve a `git push` |
| `Please tell me who you are` | Falta configurar nombre y correo | Ver capítulo 01, sección "Configurar Git" |
| Push rechazado a `master` | La rama está protegida | Trabaja en una rama y abre un PR |
| Conflicto de fusión (`CONFLICT`) | Dos cambios tocan las mismas líneas | Edita los marcadores `<<<<<<<`, `git add` y `git rebase --continue` (o `git commit`) |
| Commit hecho en la rama equivocada | Olvidaste cambiar de rama | `git switch -c nueva-rama` conserva el commit; después restablece la rama original |
