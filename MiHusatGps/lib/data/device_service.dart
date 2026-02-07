import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import 'api_service.dart';
import '../domain/models/device_model.dart';

/// Servicio para obtener información de dispositivos desde el backend.
/// 
/// Obtiene la lista de dispositivos asociados a un usuario
/// según las especificaciones de Swagger.
class DeviceService {
  /// Obtiene la lista de dispositivos para un usuario específico.
  /// 
  /// Usa GET /api/dispositivos/por-usuario/{usuarioId}?incluirDescendencia=false&ordenarPor=ultima
  /// Incluye Header: Authorization: Bearer <TOKEN_GUARDADO>
  /// Retorna una lista de DeviceModel con información completa.
  /// 
  /// [usuarioId] - ID del usuario logueado (usado si usuarioIdObjetivo es null)
  /// [usuarioIdObjetivo] - ID opcional del usuario objetivo para filtro de supervisión (solo admins)
  /// 
  /// IMPORTANTE: El usuarioId debe venir del login exitoso, NO usar valores hardcodeados
  static Future<List<DeviceModel>> getDispositivosPorUsuario(
    String usuarioId, {
    int? usuarioIdObjetivo,
  }) async {
    try {
      // Si hay un usuarioIdObjetivo, usar ese; si no, usar el usuarioId del logueado
      final usuarioIdFinal = usuarioIdObjetivo != null 
          ? usuarioIdObjetivo.toString() 
          : usuarioId;
      
      // CRÍTICO: No usar fallback hardcodeado - si no hay usuarioId, lanzar error
      if (usuarioIdFinal.isEmpty) {
        throw Exception('Usuario no autenticado. El ID del usuario es requerido para obtener dispositivos.');
      }
      
      final endpoint = '/api/dispositivos/por-usuario/$usuarioIdFinal?incluirDescendencia=false&ordenarPor=ultima';
      debugPrint('📋 Obteniendo dispositivos para usuario ID: $usuarioIdFinal${usuarioIdObjetivo != null ? ' (Filtro de Supervisión)' : ''}');
      debugPrint('📋 Endpoint: $endpoint');
      
      final response = await ApiService.getList(endpoint);
      
      if (response == null || response.isEmpty) {
        return [];
      }
      
      final dispositivos = <DeviceModel>[];
      
      for (var item in response) {
        try {
          final dispositivo = DeviceModel.fromJson(item as Map<String, dynamic>);
          dispositivos.add(dispositivo);
        } catch (e) {
          // Ignorar dispositivos con errores de parsing
        }
      }
      
      return dispositivos;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Obtiene el nombre de la marca del GPS
  static Future<String> getMarcaNombre(int marcaId) async {
    try {
      final endpoint = '${ApiConfig.marcasEndpoint}/$marcaId';
      final response = await ApiService.get(endpoint);
      
      if (response != null && response['nombre'] != null) {
        return response['nombre'] as String;
      }
      return 'Marca Desconocida';
    } catch (e) {
      return 'Marca Desconocida';
    }
  }
  
  /// Obtiene el nombre del modelo del GPS
  static Future<String> getModeloNombre(int modeloId) async {
    try {
      final endpoint = '${ApiConfig.modelosEndpoint}/$modeloId';
      final response = await ApiService.get(endpoint);
      
      if (response != null && response['nombre'] != null) {
        return response['nombre'] as String;
      }
      return 'Modelo Desconocido';
    } catch (e) {
      return 'Modelo Desconocido';
    }
  }
  
  /// Obtiene un dispositivo específico por su ID.
  /// 
  /// Usa GET /api/dispositivos/obtener/{id}
  /// Incluye Header: Authorization: Bearer <TOKEN_GUARDADO>
  /// Retorna un DeviceModel con información completa del dispositivo.
  /// 
  /// [previousDevice] - Si se proporciona y el JSON no tiene velocidad, preserva la velocidad del dispositivo anterior
  static Future<DeviceModel?> obtenerDispositivoPorId(
    String dispositivoId, {
    DeviceModel? previousDevice,
  }) async {
    try {
      final endpoint = ApiConfig.obtenerDispositivo(dispositivoId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        return null;
      }
      
      try {
        final json = response;
        
        // Si el JSON no tiene velocidad y hay un dispositivo anterior, preservar su velocidad
        if (previousDevice != null && 
            (json['velocidad'] == null && json['speed'] == null)) {
          json['velocidad'] = previousDevice.speed;
        }
        
        final dispositivo = DeviceModel.fromJson(json);
        return dispositivo;
      } catch (e) {
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }
}
