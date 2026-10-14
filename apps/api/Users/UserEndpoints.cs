namespace Api.Users;

public static class UserEndpoints
{
    public static IEndpointRouteBuilder MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/user", () => Results.Ok(SampleUsers))
            .WithName("GetUsers")
            .WithTags("User")
            .WithSummary("Returns the list of users")
            .Produces<UserResponse[]>(StatusCodes.Status200OK);

        return app;
    }

    private static readonly UserResponse[] SampleUsers =
    [
        new("Juan", "Pérez", "García", "Av. Reforma 123", "+52 55 1234 5678", "Mexico", "Mexico City", ["read", "write", "delete"], true),
        new("María", "López", "Hernández", "Calle Mayor 45", "+34 91 123 45 67", "Spain", "Madrid", ["read"], true),
        new("Carlos", "Gómez", "Rodríguez", "Av. Corrientes 987", "+54 11 4321 8765", "Argentina", "Buenos Aires", ["read", "write"], false)
    ];
}
