using System.Net;
using System.Net.Http.Json;
using Api.Users;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Api.Tests;

public class UserEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task GetUsers_ReturnsOkWithThreeUsers()
    {
        var response = await _client.GetAsync("/user");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var users = await response.Content.ReadFromJsonAsync<UserResponse[]>();
        Assert.NotNull(users);
        Assert.Equal(3, users.Length);
    }

    [Fact]
    public async Task GetUsers_ReturnsFirstSampleUserWithExpectedFields()
    {
        var users = await _client.GetFromJsonAsync<UserResponse[]>("/user");

        var first = Assert.Single(users!, u => u.Name == "Juan");
        Assert.Equal("Mexico", first.Country);
        Assert.True(first.IsActive);
        Assert.Equal(["read", "write", "delete"], first.Permissions);
    }

    [Fact]
    public async Task GetUnknownRoute_ReturnsNotFound()
    {
        var response = await _client.GetAsync("/does-not-exist");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
