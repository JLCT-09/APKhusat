import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import '../../domain/models/device_model.dart';

/// InfoWindow simplificado para modo seguimiento.
/// 
/// Muestra solo:
/// - Modelo GPS
/// - Estado (Estático, En Movimiento, Fuera de Línea)
/// - Motor (Encendido/Apagado)
/// - IMEI
/// - Velocidad
/// 
/// Se mantiene fijo sobre el vehículo y se mueve con él.
class TrackingInfoWindow extends StatefulWidget {
  final DeviceModel device;
  final double? customSpeed;

  const TrackingInfoWindow({
    super.key,
    required this.device,
    this.customSpeed,
  });

  @override
  State<TrackingInfoWindow> createState() => _TrackingInfoWindowState();
}

class _TrackingInfoWindowState extends State<TrackingInfoWindow> {
  /// Obtiene el estado del dispositivo basado en idEstadoOperativo
  Map<String, dynamic> _getEstadoFromIdOperativo() {
    final idEstado = widget.device.idEstadoOperativo;
    
    switch (idEstado) {
      case 7: // EN MOVIMIENTO
        return {
          'texto': 'En Movimiento',
          'color': const Color(0xFF4CAF50), // Verde
        };
      case 6: // ESTÁTICO
        return {
          'texto': 'Estático',
          'color': const Color(0xFF2196F3), // Azul
        };
      case 4: // FUERA DE LÍNEA
        return {
          'texto': 'Fuera de Línea',
          'color': Colors.grey, // Gris
        };
      default:
        return {
          'texto': 'Desconocido',
          'color': Colors.grey, // Gris
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    const double arrowHeight = 8.0; // Altura de la flecha
    const double borderRadius = 10.0; // Border radius
    const double arrowWidth = 20.0; // Ancho de la flecha en la base
    
    final estadoInfo = _getEstadoFromIdOperativo();
    final String estadoTexto = estadoInfo['texto'] as String;
    final Color estadoColor = estadoInfo['color'] as Color;
    
    // Usar velocidad personalizada si está disponible, sino la del dispositivo
    final velocidad = widget.customSpeed ?? widget.device.speed;
    
    return IntrinsicWidth(
      child: CustomPaint(
        painter: _TrackingInfoWindowPainter(
          arrowHeight: arrowHeight,
          borderRadius: borderRadius,
          arrowWidth: arrowWidth,
        ),
        child: IgnorePointer(
          // Hacer el widget no clickeable para que no interfiera con el mapa
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black, // Fondo negro
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Modelo GPS
                _buildInfoRow('Modelo GPS:', widget.device.modeloGps ?? widget.device.modelo ?? 'FMB920'),
                const SizedBox(height: 5),
                
                // 2. Estado (Estático, En Movimiento, Fuera de Línea)
                _buildInfoRowWithColor('Estado:', estadoTexto, estadoColor),
                const SizedBox(height: 5),
                
                // 3. Motor (Encendido/Apagado)
                _buildInfoRow('Motor:', widget.device.estadoMotor == true 
                  ? 'Encendido' 
                  : widget.device.estadoMotor == false 
                    ? 'Apagado' 
                    : 'N/A'),
                const SizedBox(height: 5),
                
                // 4. IMEI
                _buildInfoRow('IMEI:', widget.device.imei ?? 'N/A'),
                const SizedBox(height: 5),
                
                // 5. Velocidad
                _buildInfoRow('Velocidad:', '${velocidad.toStringAsFixed(1)} km/h'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye una fila de información con alineación consistente
  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80, // Ancho fijo para etiquetas
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9.0,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9.0,
              color: Colors.white,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w400,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Construye una fila de información con color personalizado para el valor
  Widget _buildInfoRowWithColor(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80, // Ancho fijo para etiquetas
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9.0,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9.0,
              color: valueColor, // Color personalizado para el estado
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter que dibuja el fondo del InfoWindow con flecha integrada
class _TrackingInfoWindowPainter extends CustomPainter {
  final double arrowHeight;
  final double borderRadius;
  final double arrowWidth;
  
  // Colores: Negro completo (#000000)
  static const Color _backgroundColor = Color(0xFF000000); // #000000 - Negro completo
  static const Color _borderColor = Color(0x66FFFFFF); // Borde blanco sutil
  static const double _borderWidth = 1.0;
  
  _TrackingInfoWindowPainter({
    required this.arrowHeight,
    required this.borderRadius,
    required this.arrowWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _backgroundColor
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;
    
    // Calcular la posición de la flecha (centro inferior)
    final arrowCenterX = size.width / 2;
    final arrowBottomY = size.height;
    
    // Crear el path del fondo con flecha integrada
    final path = Path();
    
    // Empezar desde la esquina superior izquierda (después del border radius)
    path.moveTo(borderRadius, 0);
    
    // Lado superior izquierdo
    path.lineTo(size.width - borderRadius, 0);
    
    // Esquina superior derecha
    path.quadraticBezierTo(size.width, 0, size.width, borderRadius);
    
    // Lado derecho
    path.lineTo(size.width, size.height - arrowHeight - borderRadius);
    
    // Esquina inferior derecha (antes de la flecha)
    path.quadraticBezierTo(
      size.width, 
      size.height - arrowHeight, 
      size.width - borderRadius, 
      size.height - arrowHeight
    );
    
    // Lado derecho antes de la flecha
    path.lineTo(arrowCenterX + arrowWidth / 2, size.height - arrowHeight);
    
    // Flecha: punto inferior (vértice que toca el icono)
    path.lineTo(arrowCenterX, arrowBottomY);
    
    // Flecha: lado izquierdo
    path.lineTo(arrowCenterX - arrowWidth / 2, size.height - arrowHeight);
    
    // Lado izquierdo después de la flecha
    path.lineTo(borderRadius, size.height - arrowHeight);
    
    // Esquina inferior izquierda (antes de la flecha)
    path.quadraticBezierTo(
      0, 
      size.height - arrowHeight, 
      0, 
      size.height - arrowHeight - borderRadius
    );
    
    // Lado izquierdo
    path.lineTo(0, borderRadius);
    
    // Esquina superior izquierda
    path.quadraticBezierTo(0, 0, borderRadius, 0);
    
    path.close();
    
    // Dibujar el fondo
    canvas.drawPath(path, paint);
    
    // Dibujar el borde
    canvas.drawPath(path, borderPaint);
    
    // Agregar efecto de sombra sutil
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    
    // Dibujar sombra (ligeramente desplazada)
    final shadowPath = Path.from(path);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(shadowPath, shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
