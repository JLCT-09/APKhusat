import 'package:flutter/material.dart';

/// Configuración global de la aplicación.
/// 
/// Almacena variables de sesión temporal para comunicación
/// entre diferentes partes de la aplicación.
/// 
/// ⚠️ NOTA: La URL base del servidor está en `ApiConfig.baseUrl`
/// para mantener separación de responsabilidades.
class AppConfig {
  /// Color corporativo HusatGps
  static const Color primaryColor = Color(0xFFEF1A2D);
  
  /// ID del vehículo objetivo desde una notificación.
  /// 
  /// Se establece cuando el usuario presiona una notificación
  /// y se limpia después de que el mapa se mueve al vehículo.
  static int? targetVehicleId;
}
