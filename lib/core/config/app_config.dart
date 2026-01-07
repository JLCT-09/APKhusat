/// Configuración global de la aplicación.
/// 
/// Almacena variables de sesión temporal para comunicación
/// entre diferentes partes de la aplicación.
class AppConfig {
  /// ID del vehículo objetivo desde una notificación.
  /// 
  /// Se establece cuando el usuario presiona una notificación
  /// y se limpia después de que el mapa se mueve al vehículo.
  static int? targetVehicleId;
}
