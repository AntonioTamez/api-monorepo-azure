namespace Api.Users;

public record UserResponse(
    string Name,
    string PaternalLastName,
    string MaternalLastName,
    string Address,
    string Phone,
    string Country,
    string City,
    string[] Permissions,
    bool IsActive);
