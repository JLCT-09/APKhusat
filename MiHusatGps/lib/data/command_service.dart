import '../core/config/api_config.dart';
import 'api_service.dart';

/// Servicio para enviar comandos a dispositivos GPS.
class CommandService {
  /// Envía un comando a un dispositivo.
  /// 
  /// [dispositivoId] - ID del dispositivo
  /// [comando] - Tipo de comando ('apagar' o 'restaurar')
  /// 
  /// Retorna true si el comando se envió exitosamente, false en caso contrario.
  static Future<bool> enviarComando(String dispositivoId, String comando) async {
    try {
      final endpoint = ApiConfig.enviarComando(dispositivoId);
      final body = {
        'comando': comando,
        'tipo': comando == 'apagar' ? 'CORTE_MOTOR' : 'RESTAURAR_MOTOR',
      };
      
      final response = await ApiService.post(endpoint, body);
      
      return response != null;
    } catch (e) {
      return false;
    }
  }
}
