namespace Api.Health;

public static class HealthEndpoints
{
    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/health", () => Results.Ok(new HealthResponse("Healthy")))
            .WithName("GetHealth")
            .WithTags("Health")
            .WithSummary("Reports whether the API is running")
            .Produces<HealthResponse>(StatusCodes.Status200OK);

        return app;
    }
}
