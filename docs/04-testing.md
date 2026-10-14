# 04 - Tests automáticos

Este capítulo explica por qué se escriben tests, cómo está organizado el proyecto `tests/Api.Tests` y cómo ejecutarlo. Son la base de la integración continua: sin tests, un pipeline solo comprueba que el código compila, no que funciona. Los términos nuevos están en el [glosario](00-glosario.md).

## Por qué probar automáticamente

- Detectan errores en segundos, antes de que lleguen a los usuarios.
- Permiten cambiar código con confianza: si algo se rompe, un test falla.
- El pipeline de CI los ejecuta en cada pull request y puede bloquear la fusión si fallan.

## Herramientas

| Herramienta | Para qué sirve |
| --- | --- |
| xUnit | Marco de pruebas: define qué es un test (`[Fact]`) y cómo se ejecuta |
| `Microsoft.AspNetCore.Mvc.Testing` | Proporciona `WebApplicationFactory<Program>`, que arranca la API **en memoria** |
| `dotnet test` | Compila y ejecuta todos los tests |

Un test de integración con `WebApplicationFactory` no abre puertos de red reales: crea un cliente HTTP conectado directamente a la aplicación en memoria. Así es rápido y no depende de nada externo.

## Estructura

```text
tests/Api.Tests/
├── Api.Tests.csproj          # Proyecto de tests (referencia a apps/api)
├── HealthEndpointTests.cs    # Pruebas de GET /health
├── UserEndpointTests.cs      # Pruebas de GET /user y de una ruta inexistente
├── SwaggerEnvironmentTests.cs# Swagger solo existe en Development
└── .editorconfig             # Permite guiones bajos en nombres de tests
```

El proyecto está registrado en `Monorepo.slnx` dentro de la carpeta `/tests/`, por lo que `dotnet build` y `dotnet test` desde la raíz lo incluyen.

Para que los tests puedan referenciar el punto de entrada de la API, `apps/api/Program.cs` termina con:

```csharp
public partial class Program;
```

Los programas con *top-level statements* generan una clase `Program` interna; esta línea la hace pública.

## Anatomía de un test

```csharp
[Fact]
public async Task GetHealth_ReturnsOkWithHealthyStatus()
{
    var response = await _client.GetAsync("/health");        // Act

    Assert.Equal(HttpStatusCode.OK, response.StatusCode);    // Assert
    var body = await response.Content.ReadFromJsonAsync<HealthResponse>();
    Assert.Equal("Healthy", body?.Status);
}
```

- `[Fact]` marca el método como test.
- El nombre sigue el patrón `Método_ComportamientoEsperado`.
- Se estructura en tres fases: **Arrange** (preparar), **Act** (ejecutar), **Assert** (comprobar).

## Ejecutar los tests

Desde la raíz del repositorio:

```powershell
dotnet test Monorepo.slnx
```

Salida esperada al final:

```text
Correctas! - Con error: 0, Superado: 7, Omitido: 0, Total: 7
```

(En un sistema en inglés: `Passed! - Failed: 0, Passed: 7, Skipped: 0, Total: 7`.)

Ejecutar un solo test o un grupo:

```powershell
dotnet test Monorepo.slnx --filter "FullyQualifiedName~HealthEndpointTests"
```

## TDD: rojo, verde, refactor

TDD (*Test-Driven Development*) es una disciplina en tres pasos:

1. **Rojo (RED)**: escribe un test para un comportamiento que aún no existe y comprueba que **falla**. Un test que nunca falló no demuestra nada.
2. **Verde (GREEN)**: escribe el código mínimo para que pase.
3. **Refactor**: mejora el código manteniendo los tests en verde.

Ejercicio para ver el rojo con tus propios ojos: en `apps/api/Health/HealthEndpoints.cs` cambia `"Healthy"` por `"Broken"` y ejecuta `dotnet test`. Fallarán `GetHealth_ReturnsOkWithHealthyStatus` y `GetHealth_ReturnsJsonWithLowercaseStatusProperty`, con un mensaje que muestra el valor esperado y el obtenido. Revierte el cambio y vuelven a pasar.

## Errores comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `MSB3027 ... cannot access the file 'Api.exe'` | La API sigue ejecutándose y bloquea los archivos | Detén `dotnet run` (`Ctrl+C`) y repite |
| `error CA1707` en un nombre de test | `TreatWarningsAsErrors` activo y analizador de nombres | Ya está desactivado en `tests/Api.Tests/.editorconfig`; copia ese archivo en nuevos proyectos de tests |
| `'Program' is inaccessible due to its protection level` | Falta `public partial class Program;` | Añádelo al final de `apps/api/Program.cs` |
| Un test pasa solo si se ejecuta aislado | Estado compartido entre tests | Evita estado global; cada test debe ser independiente |
| `The type or namespace 'Xunit' could not be found` | Falta `<Using Include="Xunit" />` o el paquete | Restaura con `dotnet restore` |
