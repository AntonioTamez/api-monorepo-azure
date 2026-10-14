# api-monorepo-azure

Monorepo with a .NET 10 Web API (minimal API + Swagger).

## Laboratorio DevOps

Este repositorio también es un laboratorio práctico para aprender DevOps desde cero. Partiendo de una API mínima en .NET, se añaden paso a paso tests, contenedores con Docker, integración y entrega continuas con GitHub Actions, infraestructura como código con Terraform y despliegue en Azure. Cada capítulo explica los conceptos desde el principio, cómo ejecutar los comandos, qué salida esperar y qué errores son comunes. Si no sabes por dónde empezar, lee los capítulos en orden.

### Índice de la documentación

| Capítulo | Contenido |
| --- | --- |
| [00 - Glosario](docs/00-glosario.md) | Definición de todos los términos (CI, CD, runner, Terraform, OIDC...) |
| [01 - Requisitos y setup](docs/01-requisitos-y-setup.md) | Instalar y verificar las herramientas en Windows |
| [02 - Git y ramas](docs/02-git-y-ramas.md) | Flujo de ramas, Conventional Commits, pull requests y protección de ramas |
| [03 - La aplicación](docs/03-la-aplicacion.md) | La API, el endpoint `/health` y los archivos de configuración del repositorio |
| [04 - Testing](docs/04-testing.md) | Tests con xUnit, `tests/Api.Tests`, TDD y cómo ejecutarlos |

Los capítulos siguientes (la aplicación, tests, Docker, GitHub Actions, Terraform, Azure) se irán añadiendo a esta tabla.

## Structure

```
.
├── Monorepo.slnx          # Solution file
└── apps/
    └── api/               # ASP.NET Core Web API (net10.0)
        ├── Program.cs
        ├── Health/        # GET /health endpoint
        └── Users/         # GET /user endpoint + response model
└── tests/
    └── Api.Tests/         # xUnit integration tests (WebApplicationFactory)
```

## Prerequisites

- [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0) — verify with `dotnet --version`
- (Optional) Git

For HTTPS in local development, trust the dev certificate once:

```bash
dotnet dev-certs https --trust
```

## Commands

Run everything from the repository root.

```bash
# Restore dependencies
dotnet restore

# Build the whole solution
dotnet build

# Run the API (http://localhost:5251, https://localhost:7071)
dotnet run --project apps/api

# Run with the https profile
dotnet run --project apps/api --launch-profile https

# Run with hot reload
dotnet watch --project apps/api

# Release build / publish
dotnet build -c Release
dotnet publish apps/api -c Release -o ./publish

# Clean build outputs
dotnet clean
```

## Endpoints

| Method | Path    | Auth | Description              |
| ------ | ------- | ---- | ------------------------ |
| GET    | `/user` | None | Returns the list of users |
| GET    | `/health` | None | Returns `{"status":"Healthy"}` |

- Swagger UI: <http://localhost:5251/swagger>
- OpenAPI JSON: <http://localhost:5251/swagger/v1/swagger.json>

Quick test:

```bash
curl http://localhost:5251/user
```

Response item:

```json
{
  "name": "Juan",
  "paternalLastName": "Pérez",
  "maternalLastName": "García",
  "address": "Av. Reforma 123",
  "phone": "+52 55 1234 5678",
  "country": "Mexico",
  "city": "Mexico City",
  "permissions": ["read", "write", "delete"],
  "isActive": true
}
```

> The data is currently hardcoded in `apps/api/Users/UserEndpoints.cs`.

## Notes

- Swagger is only enabled in the Development environment.
- Change the port with `dotnet run --project apps/api --urls http://localhost:8080`.
- If a build fails with locked files, stop any running `Api.exe` process or run `dotnet build-server shutdown`.

## Adding more projects to the monorepo

```bash
# New project
dotnet new xunit -n Api.Tests -o tests/Api.Tests
dotnet add tests/Api.Tests reference apps/api

# Register it in the solution
dotnet sln add tests/Api.Tests

# Run all tests
dotnet test
```
