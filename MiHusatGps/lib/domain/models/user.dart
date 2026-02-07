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
  final int? rolId; // ID numérico del rol (1=Admin, 2=Distribuidor, 3=Cliente, etc.)
  final String? vehicleId; // Solo para clientes

  User({
    required this.id,
    required this.nombre,
    required this.email,
    required this.token,
    required this.role,
    this.rolId,
    this.vehicleId,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;
  
  /// Verifica si el usuario es admin basándose en rolId (rolId == 1)
  bool get isAdminByRolId => rolId == 1;
}
