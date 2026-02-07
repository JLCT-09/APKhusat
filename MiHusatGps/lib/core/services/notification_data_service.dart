/// Servicio para manejar datos de notificaciones pendientes.
/// 
/// Almacena temporalmente los datos de notificaciones (deviceId, coordenadas)
/// para que puedan ser utilizados al navegar al MapScreen.
class NotificationDataService {
  static final NotificationDataService _instance = NotificationDataService._internal();
  factory NotificationDataService() => _instance;
  NotificationDataService._internal();

  int? _pendingDeviceId;
  double? _pendingLatitude;
  double? _pendingLongitude;

  /// Guarda los datos de notificación pendiente
  void setPendingNotification(int deviceId, double latitude, double longitude) {
    _pendingDeviceId = deviceId;
    _pendingLatitude = latitude;
    _pendingLongitude = longitude;
  }

  /// Obtiene y limpia los datos de notificación pendiente
  Map<String, dynamic>? getAndClearPendingNotification() {
    if (_pendingDeviceId != null && _pendingLatitude != null && _pendingLongitude != null) {
      final data = {
        'deviceId': _pendingDeviceId!,
        'latitude': _pendingLatitude!,
        'longitude': _pendingLongitude!,
      };
      _pendingDeviceId = null;
      _pendingLatitude = null;
      _pendingLongitude = null;
      return data;
    }
    return null;
  }

  /// Verifica si hay datos de notificación pendientes
  bool hasPendingNotification() {
    return _pendingDeviceId != null && _pendingLatitude != null && _pendingLongitude != null;
  }
}
