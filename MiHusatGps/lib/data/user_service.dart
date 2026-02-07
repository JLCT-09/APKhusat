import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/storage_service.dart';
import 'api_service.dart';

/// Modelo de datos del usuario desde la API
class UserProfile {
  final String nombreCompleto;
  final String email;
  final String telefono;
  final int? rolId; // ID numérico del rol (1=Admin, 2=Distribuidor, etc.)

  UserProfile({
    required this.nombreCompleto,
    required this.email,
    required this.telefono,
    this.rolId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nombreCompleto: json['nombreCompleto']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      rolId: json['rolId'] != null
          ? ((json['rolId'] is int)
              ? json['rolId'] as int
              : int.tryParse(json['rolId']?.toString() ?? ''))
          : null,
    );
  }
}

/// Modelo de usuario para la lista de usuarios (filtro de supervisión)
class UsuarioLista {
  final int id;
  final String nombreUsuario;
  final String nombreCompleto;
  final int rolId;
  final String email;
  final int? distribuidorPadreId;
  final String? telefono;
  final String? husoHorario;
  final String? contacto;
  final String? direccion;
  final String? paginaWeb;
  final String? fechaCreacion;
  final String? fechaActualizacion;

  UsuarioLista({
    required this.id,
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.rolId,
    required this.email,
    this.distribuidorPadreId,
    this.telefono,
    this.husoHorario,
    this.contacto,
    this.direccion,
    this.paginaWeb,
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory UsuarioLista.fromJson(Map<String, dynamic> json) {
    return UsuarioLista(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      nombreUsuario: json['nombreUsuario']?.toString() ?? '',
      nombreCompleto: json['nombreCompleto']?.toString() ?? '',
      rolId: (json['rolId'] is int) ? json['rolId'] : int.tryParse(json['rolId']?.toString() ?? '') ?? 0,
      email: json['email']?.toString() ?? '',
      distribuidorPadreId: json['distribuidorPadreId'] != null
          ? ((json['distribuidorPadreId'] is int)
              ? json['distribuidorPadreId'] as int
              : int.tryParse(json['distribuidorPadreId']?.toString() ?? ''))
          : null,
      telefono: json['telefono']?.toString(),
      husoHorario: json['husoHorario']?.toString(),
      contacto: json['contacto']?.toString(),
      direccion: json['direccion']?.toString(),
      paginaWeb: json['paginaWeb']?.toString(),
      fechaCreacion: json['fechaCreacion']?.toString(),
      fechaActualizacion: json['fechaActualizacion']?.toString(),
    );
  }
}

/// Servicio para obtener información del usuario desde el backend.
class UserService {
  /// Obtiene los datos del perfil del usuario.
  /// 
  /// Usa GET /api/usuarios/obtener/{usuarioId}
  /// Retorna un UserProfile con nombreCompleto, email y telefono.
  static Future<UserProfile?> obtenerUsuario(String usuarioId) async {
    try {
      final endpoint = ApiConfig.obtenerUsuario(usuarioId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        debugPrint('⚠️ No se pudo obtener datos del usuario');
        return null;
      }
      
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('⚠️ Error al obtener datos del usuario: $e');
      return null;
    }
  }

  /// Lista todos los usuarios disponibles (para filtro de supervisión).
  /// 
  /// Usa GET /api/usuarios/listar
  /// Retorna una lista de UsuarioLista con id, nombreUsuario, nombreCompleto, rolId y email.
  /// 
  /// IMPORTANTE: Solo usuarios con rolId == 1 (Admin) pueden acceder a este endpoint.
  static Future<List<UsuarioLista>> listarUsuarios() async {
    try {
      // Validar que el usuario es admin (rolId == 1)
      final rolId = await StorageService.getUserRolId();
      
      if (rolId != 1) {
        debugPrint('❌ Acceso denegado: Solo usuarios con rolId == 1 (Admin) pueden listar usuarios. RolId actual: $rolId');
        return [];
      }
      
      final endpoint = ApiConfig.listarUsuarios;
      final response = await ApiService.getList(endpoint);
      
      if (response == null || response.isEmpty) {
        debugPrint('⚠️ No se pudo obtener lista de usuarios o está vacía');
        return [];
      }
      
      final usuarios = <UsuarioLista>[];
      
      for (var item in response) {
        try {
          final usuario = UsuarioLista.fromJson(item as Map<String, dynamic>);
          usuarios.add(usuario);
        } catch (e) {
          debugPrint('⚠️ Error al parsear usuario: $e');
        }
      }
      
      debugPrint('✅ Listados ${usuarios.length} usuarios');
      return usuarios;
    } catch (e) {
      debugPrint('❌ Error al listar usuarios: $e');
      return [];
    }
  }
}
