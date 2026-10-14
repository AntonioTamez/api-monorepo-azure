# Feature: devops-lab

Objective: turn this repo into a teaching lab (GitHub Actions, Docker, Terraform, Azure) for a junior dev with zero DevOps knowledge. Docs in Spanish; identifiers in English.
Plan: C:\Users\anton\.claude\plans\eres-un-dev-ops-wise-whale.md
Delivery strategy: ask-on-risk (forecast >400 lines; slices decided before next commit beyond budget).

## Tasks
- [x] T1 Docs base: glossary, setup, git flow, README index
- [x] T2 App hardening: editorconfig, global.json, Directory.Build.props, /health, Swagger dev-only
- [x] T3 Tests project (xunit, RED->GREEN)
- [ ] T4 Dockerfile multi-stage + docs
- [ ] T5 CI workflow + dependabot + PR template + docs
- [ ] T6 Terraform bootstrap + modules + docs
- [ ] T7 Terraform envs dev/prod + docs
- [ ] T8 OIDC GitHub<->Azure + docs
- [ ] T9 CD workflows + docs
- [ ] T10 Costs, troubleshooting, exercises

## Evidence log
(route per task, commits, checks)
- T1: delegated writer; commit c8462f7 (docs: glossary, setup, git flow, README index). Check: structural readback only (passive docs).
- T2: delegated writer; commit 5e79298 (feat(api): health endpoint + repo config). Check: `dotnet build Monorepo.slnx --artifacts-path <scratch>` -> 0 warnings, 0 errors (default output was locked by a running Api process).
- T3: delegated writer; tests/Api.Tests (7 tests). RED: observed via deliberate mutation of /health ("Healthy"->"Broken"): Failed 2, Passed 5; reverted. GREEN: Failed 0, Passed 7 (run with --artifacts-path because a user-owned Api.exe PID 14496 locks apps/api/bin; plain `dotnet test Monorepo.slnx` fails with MSB3027 until that process stops). Commit hash in the next line.
- T3 commit: 3e7c055
