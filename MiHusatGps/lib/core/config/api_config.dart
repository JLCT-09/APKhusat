/// Configuración de la API del backend HusatGps.
/// 
/// Define la URL base del servidor y endpoints principales.
class ApiConfig {
  // URL del servidor de producción HusatGps
  // ⚠️ IMPORTANTE: Para cambiar la IP del servidor, actualiza solo esta constante
  static const String baseUrl = 'http://34.132.25.84:8080';
  
  // Endpoints de Autenticación
  static const String loginEndpoint = '/api/AutenticacionControlador/login';
  
  // Endpoints de Usuarios
  static String obtenerUsuario(String usuarioId) => '/api/usuarios/obtener/$usuarioId';
  static const String listarUsuarios = '/api/usuarios/listar';
  
  // Endpoints de Dispositivos
  // Nota: El endpoint completo incluye query parameters: ?incluirDescendencia=false&ordenarPor=ultima
  // Se construye en DeviceService.getDispositivosPorUsuario()
  static String dispositivosPorUsuario(String usuarioId) => '/api/dispositivos/por-usuario/$usuarioId';
  static String obtenerDispositivo(String dispositivoId) => '/api/dispositivos/obtener/$dispositivoId';
  
  // Endpoints de GPS
  static String ultimaUbicacion(String dispositivoId) => '/api/gps/ultima-ubicacion/$dispositivoId';
  // Nota: El endpoint de historial puede incluir parámetros de fecha: ?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
  static String historialGps(String dispositivoId) => '/api/gps/historial/$dispositivoId';
  
  // Endpoints de Telemetría (Estado de Dispositivo)
  // Batch: Obtiene estado de múltiples dispositivos en una sola llamada
  // Usa parámetros repetidos: ids=6&ids=2&ids=5 en lugar de ids=6,2,5
  static String estadoDispositivoBatch(List<int> ids) {
    final idsList = ids.map((id) => id.toString()).toList();
    // Construir URI con parámetros repetidos: ids=6&ids=2&ids=5
    final uri = Uri(
      path: '/api/estado-dispositivo/batch',
      queryParameters: {'ids': idsList},
    );
    // Retornar solo el path con query parameters (sin baseUrl)
    // Uri.queryParameters genera automáticamente ids=6&ids=2&ids=5 cuando hay múltiples valores
    return '${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'}';
  }
  // Individual: Obtiene estado detallado de un dispositivo (batería, energía externa, motor, odómetro)
  static String estadoDispositivo(String dispositivoId) => '/api/estado-dispositivo/$dispositivoId';
  // Estado Operativo: Obtiene el estado operativo de un dispositivo (codigoEstadoOperativo, idEstadoOperativo)
  static String estadoOperativoDispositivo(String dispositivoId) => '/api/estado-dispositivo/$dispositivoId/estado';
  
  // Endpoints de Marca y Modelo (para mostrar información completa)
  static const String marcasEndpoint = '/api/MarcaGpsControlador';
  static const String modelosEndpoint = '/api/ModeloGpsControlador';
  
  // Endpoints de Comandos
  static String enviarComando(String dispositivoId) => '/api/comandos/enviar/$dispositivoId';
}
