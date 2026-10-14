using System.Net;
using System.Net.Http.Json;
using Api.Health;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Api.Tests;

public class HealthEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task GetHealth_ReturnsOkWithHealthyStatus()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<HealthResponse>();
        Assert.Equal("Healthy", body?.Status);
    }

    [Fact]
    public async Task GetHealth_ReturnsJsonWithLowercaseStatusProperty()
    {
        var json = await _client.GetStringAsync("/health");

        Assert.Equal("""{"status":"Healthy"}""", json);
    }
}
