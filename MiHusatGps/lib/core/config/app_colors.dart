import 'package:flutter/material.dart';

/// Sistema de colores centralizado para toda la aplicación
/// 
/// Mantiene consistencia visual en toda la aplicación
class AppColors {
  // Colores Principales
  static const Color primary = Color(0xFFEF1A2D); // Rojo corporativo
  static const Color primaryLight = Color(0xFFFF5252);
  static const Color primaryDark = Color(0xFFC62828);
  
  // Estados Operativos
  static const Color success = Color(0xFF4CAF50); // Verde - En Movimiento
  static const Color info = Color(0xFF2196F3); // Azul - Estático
  static const Color warning = Color(0xFFFF9800); // Amarillo
  static const Color error = Color(0xFFF44336); // Rojo - Error
  static const Color offline = Color(0xFF9E9E9E); // Gris - Fuera de Línea
  
  // Textos
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textWhite = Colors.white;
  
  // Fondos
  static const Color background = Colors.white;
  static const Color surface = Color(0xFFF5F5F5);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Overlays
  static const Color overlayDark = Color(0x80000000); // 50% opacity
  static const Color overlayLight = Color(0x40FFFFFF); // 25% opacity
}
