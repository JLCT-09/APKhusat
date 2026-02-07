import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

/// Thumb personalizado para el slider de reproducción del historial
/// Muestra un icono de carro en lugar del círculo estándar
class CustomSliderThumb extends SliderComponentShape {
  final BitmapDescriptor vehicleIcon;
  final double thumbSize;
  
  CustomSliderThumb({
    required this.vehicleIcon,
    this.thumbSize = 32.0,
  });
  
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbSize, thumbSize);
  }
  
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // Convertir BitmapDescriptor a Image
    // Nota: Esto requiere acceso a los bytes del icono
    // Por simplicidad, dibujamos un círculo con el icono dentro
    final canvas = context.canvas;
    
    // Dibujar círculo de fondo
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, thumbSize / 2, backgroundPaint);
    
    // Dibujar borde
    final borderPaint = Paint()
      ..color = const Color(0xFFEF1A2D) // Color corporativo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, thumbSize / 2 - 1, borderPaint);
    
    // Dibujar icono de carro (simplificado - un rectángulo redondeado)
    final carPaint = Paint()
      ..color = const Color(0xFFEF1A2D)
      ..style = PaintingStyle.fill;
    
    final carRect = Rect.fromCenter(
      center: center,
      width: thumbSize * 0.6,
      height: thumbSize * 0.4,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, const Radius.circular(4)),
      carPaint,
    );
  }
}
