import 'dart:math' as math;

/// Helper centralizado para cálculos de distancia geográfica
/// 
/// Implementa la fórmula de Haversine para calcular distancias entre coordenadas GPS
class DistanceHelper {
  /// Radio de la Tierra en metros
  static const double earthRadiusMeters = 6371000.0;

  /// Calcula la distancia entre dos puntos geográficos usando la fórmula de Haversine
  /// 
  /// [lat1] - Latitud del primer punto en grados
  /// [lon1] - Longitud del primer punto en grados
  /// [lat2] - Latitud del segundo punto en grados
  /// [lon2] - Longitud del segundo punto en grados
  /// 
  /// Retorna la distancia en metros
  static double calculateDistanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calcula la distancia entre dos puntos geográficos y retorna en kilómetros
  /// 
  /// [lat1] - Latitud del primer punto en grados
  /// [lon1] - Longitud del primer punto en grados
  /// [lat2] - Latitud del segundo punto en grados
  /// [lon2] - Longitud del segundo punto en grados
  /// 
  /// Retorna la distancia en kilómetros
  static double calculateDistanceInKilometers(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistanceInMeters(lat1, lon1, lat2, lon2) / 1000.0;
  }

  /// Convierte grados a radianes
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
