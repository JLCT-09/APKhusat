/// Configuración de la API del backend HusatGps.
/// 
/// Define la URL base del servidor y endpoints principales.
/// Cambiar baseUrl cuando se tenga la IP del servidor.
class ApiConfig {
  // URL del servidor de producción HusatGps
  static const String baseUrl = 'http://34.16.74.196:8080';
  
  // Endpoints de Autenticación
  static const String loginEndpoint = '/api/AutenticacionControlador/login';
  
  // Endpoints de Dispositivos
  // Nota: El endpoint completo incluye query parameters: ?incluirDescendencia=false&ordenarPor=ultima
  // Se construye en DeviceService.getDispositivosPorUsuario()
  static String dispositivosPorUsuario(String usuarioId) => '/api/dispositivos/por-usuario/$usuarioId';
  
  // Endpoints de GPS
  static String ultimaUbicacion(String dispositivoId) => '/api/gps/ultima-ubicacion/$dispositivoId';
  // Nota: El endpoint de historial puede incluir parámetros de fecha: ?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
  static String historialGps(String dispositivoId) => '/api/gps/historial/$dispositivoId';
  
  // Endpoints de Marca y Modelo (para mostrar información completa)
  static const String marcasEndpoint = '/api/MarcaGpsControlador';
  static const String modelosEndpoint = '/api/ModeloGpsControlador';
}
