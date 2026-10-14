using Api.Health;
using Api.Users;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Swagger exposes the API surface, so it is only available in Development.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapHealthEndpoints();
app.MapUserEndpoints();

app.Run();

// Makes the entry point visible to the integration tests (WebApplicationFactory<Program>).
public partial class Program;
