enum UserRole {
  admin,
  client,
}

class User {
  final String id;
  final String nombre;
  final String email;
  final String token;
  final UserRole role;
  final String? vehicleId; // Solo para clientes

  User({
    required this.id,
    required this.nombre,
    required this.email,
    required this.token,
    required this.role,
    this.vehicleId,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;
}
