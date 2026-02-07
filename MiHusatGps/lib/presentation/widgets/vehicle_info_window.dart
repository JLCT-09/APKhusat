import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';

/// InfoWindow que muestra información del vehículo con flecha integrada.
/// 
/// Diseño: Burbuja de información con flecha que apunta al icono del vehículo.
/// La flecha está integrada en el fondo usando CustomPainter.
/// 
/// Muestra:
/// - Modelo GPS
/// - Estado (Estático, En Movimiento, Fuera de Línea)
/// - Motor (Encendido/Apagado)
/// - Kilometraje
/// - Hoy (fecha actual)
/// - Bat. GPS
/// - Energía Ext
/// - IMEI
/// - Coordenadas (Latitud, Longitud)
class VehicleInfoWindow extends StatefulWidget {
  final DeviceModel device;
  final DateTime lastUpdate;
  final LatLng? position;
  final double? customLatitude;
  final double? customLongitude;
  final double? customSpeed;
  final String? customStatus;

  const VehicleInfoWindow({
    super.key,
    required this.device,
    required this.lastUpdate,
    this.position,
    this.customLatitude,
    this.customLongitude,
    this.customSpeed,
    this.customStatus,
  });

  @override
  State<VehicleInfoWindow> createState() => _VehicleInfoWindowState();
}

class _VehicleInfoWindowState extends State<VehicleInfoWindow> {
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

  /// Formatea la fecha de hoy
  String _getFechaHoy() {
    try {
      final hoy = DateTime.now();
      return DateFormat('dd/MM/yyyy').format(hoy);
    } catch (e) {
      return 'N/A';
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
    
    return IntrinsicWidth(
      child: CustomPaint(
        painter: _InfoWindowPainter(
          arrowHeight: arrowHeight,
          borderRadius: borderRadius,
          arrowWidth: arrowWidth,
        ),
            child: IgnorePointer(
          // Hacer el widget no clickeable para que no interfiera con el mapa
            child: Container(
            padding: const EdgeInsets.all(16), // Aumentado de 14 a 16 para mejor legibilidad
            color: Colors.transparent, // Fondo transparente (el CustomPainter dibuja el fondo)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Modelo GPS
                _buildInfoRow('Modelo GPS:', widget.device.modeloGps ?? widget.device.modelo ?? 'FMB920'),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 2. Estado (Estático, En Movimiento, Fuera de Línea)
                _buildInfoRowWithColor('Estado:', estadoTexto, estadoColor),
                const SizedBox(height: 6), // Aumentado de 5 a 6

                
                // 3. Motor (Encendido/Apagado)
                _buildInfoRow('Motor:', widget.device.estadoMotor == true 
                  ? 'Encendido' 
                  : widget.device.estadoMotor == false 
                    ? 'Apagado' 
                    : 'N/A'),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 4. Kilometraje
                _buildInfoRow('Kilometraje:', widget.device.kilometrajeTotal != null 
                  ? '${widget.device.kilometrajeTotal!.toStringAsFixed(2)} km' 
                  : '0.00 km'),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 5. Hoy (fecha actual)
                _buildInfoRow('Hoy:', _getFechaHoy()),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 6. Bat. GPS
                _buildInfoRow('Bat. GPS:', '${widget.device.bateria ?? 0}%'),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 7. Energía Ext
                _buildInfoRow('Energía Ext:', widget.device.energiaExterna != null 
                  ? '${widget.device.energiaExterna!.toStringAsFixed(2)}V' 
                  : '0.00V'),
                const SizedBox(height: 6), // Aumentado de 5 a 6
                
                // 8. IMEI
                _buildInfoRow('IMEI:', widget.device.imei ?? 'N/A'),
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
          width: 90, // Ancho fijo para etiquetas para alineación consistente
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.0, // Aumentado de 9.0 a 10.0 para mejor legibilidad
              color: Colors.white.withOpacity(0.95), // Mejor contraste
              fontWeight: FontWeight.w500,
              height: 1.3, // Aumentado de 1.2 a 1.3
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10.0, // Aumentado de 9.0 a 10.0 para mejor legibilidad
              color: Colors.white.withOpacity(0.95), // Mejor contraste
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w400,
              height: 1.3, // Aumentado de 1.2 a 1.3
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
          width: 90, // Ancho fijo para etiquetas para alineación consistente
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.0, // Aumentado de 9.0 a 10.0
              color: Colors.white.withOpacity(0.95), // Mejor contraste
              fontWeight: FontWeight.w500,
              height: 1.3, // Aumentado de 1.2 a 1.3
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10.0, // Aumentado de 9.0 a 10.0
              color: valueColor, // Color personalizado para el estado
              fontWeight: FontWeight.w600,
              height: 1.3, // Aumentado de 1.2 a 1.3
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Formatea la última actualización en formato 24h (HH:mm:ss)
  String _formatLastUpdate(DateTime dateTime) {
    try {
      // Usar zona horaria local del dispositivo
      final localDateTime = dateTime.toLocal();
      return DateFormat('HH:mm:ss').format(localDateTime);
    } catch (e) {
      return 'N/A';
    }
  }
}

/// CustomPainter que dibuja el fondo del InfoWindow con flecha integrada
class _InfoWindowPainter extends CustomPainter {
  final double arrowHeight;
  final double borderRadius;
  final double arrowWidth;
  
  // Colores: Negro semi-transparente para mejor visibilidad del mapa detrás
  static const Color _backgroundColor = Color(0xE6000000); // Negro con ~90% opacidad (más transparente)
  static const Color _borderColor = Color(0x99FFFFFF); // Borde blanco más visible
  static const double _borderWidth = 1.0;
  
  _InfoWindowPainter({
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
    
    // Flecha: punto inferior (vértice que toca el icono) - INTEGRADO CON path.lineTo
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
