import 'package:flutter/material.dart';

/// Sistema de espaciado centralizado para toda la aplicación
/// 
/// Mantiene consistencia en padding y margins
class AppSpacing {
  // Espaciado Estándar
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  // Padding de Contenedores
  static const EdgeInsets containerPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: 12.0,
  );
  
  // Separación entre Elementos
  static const double fieldSpacing = 20.0; // Entre campos de formulario
  static const double sectionSpacing = lg; // Entre secciones
  static const double listItemSpacing = sm; // Entre items de lista
}
