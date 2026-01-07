class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed; // Velocidad en m/s
  final double? accuracy; // Precisión en metros

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.accuracy,
  });

  // Convertir a LatLng para Google Maps
  Map<String, double> toLatLng() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'accuracy': accuracy,
    };
  }

  // Crear desde JSON
  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      speed: json['speed'] as double?,
      accuracy: json['accuracy'] as double?,
    );
  }
}
