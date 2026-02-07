/// Modelo de alerta para el historial de notificaciones.
class AlertModel {
  final String id;
  final String type; // 'speed' o 'coverage'
  final String deviceId;
  final String placa;
  final String message;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? speed; // Para alertas de velocidad
  final bool isRead;

  AlertModel({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.placa,
    required this.message,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.speed,
    this.isRead = false,
  });

  /// Crea una alerta desde JSON
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      type: json['type'] as String,
      deviceId: json['deviceId'] as String,
      placa: json['placa'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Convierte la alerta a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'deviceId': deviceId,
      'placa': placa,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'isRead': isRead,
    };
  }

  /// Crea una copia con campos modificados
  AlertModel copyWith({
    String? id,
    String? type,
    String? deviceId,
    String? placa,
    String? message,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? speed,
    bool? isRead,
  }) {
    return AlertModel(
      id: id ?? this.id,
      type: type ?? this.type,
      deviceId: deviceId ?? this.deviceId,
      placa: placa ?? this.placa,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Obtiene el título de la alerta
  String get title {
    switch (type) {
      case 'speed':
        return '⚠️ Exceso de Velocidad';
      case 'coverage':
        return '📡 Sin Cobertura';
      default:
        return 'Alerta';
    }
  }

  /// Obtiene el icono de la alerta
  String get icon {
    switch (type) {
      case 'speed':
        return '⚠️';
      case 'coverage':
        return '📡';
      default:
        return '🔔';
    }
  }
}
