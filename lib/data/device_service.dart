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
  /// Usa GET /api/dispositivos/por-usuario/6?incluirDescendencia=false&ordenarPor=ultima
  /// (Usa el ID 6 que es el de Jherson)
  /// Incluye Header: Authorization: Bearer <TOKEN_GUARDADO>
  /// Retorna una lista de DeviceModel con información completa.
  static Future<List<DeviceModel>> getDispositivosPorUsuario(String usuarioId) async {
    try {
      final userId = usuarioId.isEmpty ? '6' : usuarioId;
      final endpoint = '/api/dispositivos/por-usuario/$userId?incluirDescendencia=false&ordenarPor=ultima';
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
}
