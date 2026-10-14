# Feature: devops-lab

Objective: turn this repo into a teaching lab (GitHub Actions, Docker, Terraform, Azure) for a junior dev with zero DevOps knowledge. Docs in Spanish; identifiers in English.
Plan: C:\Users\anton\.claude\plans\eres-un-dev-ops-wise-whale.md
Delivery strategy: ask-on-risk (forecast >400 lines; slices decided before next commit beyond budget).

## Tasks
- [x] T1 Docs base: glossary, setup, git flow, README index
- [x] T2 App hardening: editorconfig, global.json, Directory.Build.props, /health, Swagger dev-only
- [x] T3 Tests project (xunit, RED->GREEN)
- [x] T4 Dockerfile multi-stage + docs
- [x] T5 CI workflow + dependabot + PR template + docs
- [x] T6 Terraform bootstrap + modules + docs
- [x] T7 Terraform envs dev/prod + docs
- [ ] T8 OIDC GitHub<->Azure + docs
- [ ] T9 CD workflows + docs
- [ ] T10 Costs, troubleshooting, exercises

## Evidence log
(route per task, commits, checks)
- T1: delegated writer; commit c8462f7 (docs: glossary, setup, git flow, README index). Check: structural readback only (passive docs).
- T2: delegated writer; commit 5e79298 (feat(api): health endpoint + repo config). Check: `dotnet build Monorepo.slnx --artifacts-path <scratch>` -> 0 warnings, 0 errors (default output was locked by a running Api process).
- T3: delegated writer; tests/Api.Tests (7 tests). RED: observed via deliberate mutation of /health ("Healthy"->"Broken"): Failed 2, Passed 5; reverted. GREEN: Failed 0, Passed 7 (run with --artifacts-path because a user-owned Api.exe PID 14496 locks apps/api/bin; plain `dotnet test Monorepo.slnx` fails with MSB3027 until that process stops). Commit hash in the next line.
- T3 commit: 3e7c055
- T4: delegated writer; commit af4c1ca (feat(docker): Dockerfile multi-stage, .dockerignore, docs/05-docker.md). Checks: `dotnet publish apps/api/Api.csproj -c Release` OK (local equivalent of the Dockerfile publish step). `docker build` NOT run: Docker CLI present (29.8.0) but Docker Desktop daemon not running (npipe dockerDesktopLinuxEngine missing). Image build/run/curl /health remain unverified; run per docs/05-docker.md.
- T5: delegated writer; commit 435fc48 (ci: workflow, dependabot, PR template, docs/06-github-actions.md). Checks (with --artifacts-path scratch): YAML parse OK (pyyaml; actionlint not installed); `dotnet format Monorepo.slnx --verify-no-changes` exit 0; `dotnet build -c Release` 0 warnings, 0 errors; `dotnet test -c Release --collect:"XPlat Code Coverage"` Passed 7, coverage.cobertura.xml produced; `dotnet list package --vulnerable --include-transitive` no vulnerable packages (Api, Api.Tests). Workflow itself not executed on GitHub.
- T6: delegated writer; commit 2b7a05e (feat(infra): bootstrap scripts, modules resource_group/acr/monitoring/app_service, docs 07 and 08, README index). Checks: terraform and az NOT installed on this machine, so `terraform fmt -check`, `init -backend=false` and `validate` were NOT run; HCL written by hand with fmt-style alignment, unverified. Bootstrap scripts not executed. azurerm 4.x argument names confirmed via Context7 (container_registry_use_managed_identity in site_config, application_stack docker_image_name/docker_registry_url).
- T7: delegated writer; commit 2e83aea (feat(infra): envs dev/prod, infra/.gitignore (added in T6 commit), docs/09, README index). Checks: same as T6 (no terraform available); .terraform.lock.hcl NOT generated, so it is not committed (it will appear after the first `terraform init`; commit it then). Doc chapters renumbered: OIDC=10, CD=11, ops=12.
