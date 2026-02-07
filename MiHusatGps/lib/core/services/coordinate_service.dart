import '../../data/gps_service.dart';

/// Servicio centralizado para obtener coordenadas válidas de un dispositivo.
/// 
/// Regla de Oro: Si las coordenadas actuales son 0.0, llama automáticamente
/// al endpoint /api/gps/ultima-ubicacion/{id} para obtener las coordenadas reales.
class CoordinateService {
  /// Obtiene las coordenadas válidas de un dispositivo.
  /// 
  /// Prioridad:
  /// 1. Coordenadas actuales del dispositivo (si son válidas)
  /// 2. Endpoint /api/gps/ultima-ubicacion/{id} (si las actuales son 0.0)
  /// 3. Última ubicación del historial (fallback final)
  /// 
  /// Retorna un Map con 'latitude', 'longitude', 'speed', 'rumbo', 'timestamp' y 'isFromHistory' (bool).
  static Future<Map<String, dynamic>> getValidCoordinates(
    String dispositivoId,
    double currentLat,
    double currentLng,
  ) async {
    // Validar coordenadas actuales
    if (_isValidCoordinate(currentLat, currentLng)) {
      return {
        'latitude': currentLat,
        'longitude': currentLng,
        'isFromHistory': false,
      };
    }
    
    // REGLA DE ORO: Si las coordenadas son 0.0, llamar al endpoint ultima-ubicacion
    try {
      final int id = int.tryParse(dispositivoId) ?? 0;
      if (id > 0) {
        final ultimaUbicacion = await GpsService.fetchLastLocation(id);
        
        if (ultimaUbicacion != null && 
            _isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
          return {
            'latitude': ultimaUbicacion.latitude,
            'longitude': ultimaUbicacion.longitude,
            'speed': ultimaUbicacion.speed,
            'rumbo': ultimaUbicacion.rumbo,
            'timestamp': ultimaUbicacion.timestamp,
            'isFromHistory': false, // Viene del endpoint, no del historial
          };
        }
      }
    } catch (e) {
      // Si falla el endpoint, continuar con historial
    }
    
    // Fallback: Buscar en historial si el endpoint no devolvió datos válidos
    try {
      final fechaDesde = DateTime.now().subtract(const Duration(hours: 24));
      final historial = await GpsService.getHistorial(
        dispositivoId,
        fechaDesde: fechaDesde,
        fechaHasta: DateTime.now(),
      );
      
      // Buscar el último punto válido (de más reciente a más antiguo)
      for (var ubicacion in historial.reversed) {
        if (_isValidCoordinate(ubicacion.latitude, ubicacion.longitude)) {
          return {
            'latitude': ubicacion.latitude,
            'longitude': ubicacion.longitude,
            'speed': ubicacion.speed,
            'rumbo': ubicacion.rumbo,
            'timestamp': ubicacion.timestamp,
            'isFromHistory': true,
          };
        }
      }
    } catch (e) {
      // Si hay error, retornar las coordenadas actuales (aunque sean 0.0)
    }
    
    // Si no se encontró nada válido, retornar las coordenadas actuales
    return {
      'latitude': currentLat,
      'longitude': currentLng,
      'isFromHistory': false,
    };
  }
  
  /// Valida si una coordenada es válida (no es 0.0, 0.0 o nula)
  static bool _isValidCoordinate(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }
}
