import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/coordinate_service.dart';

/// InfoWindow que muestra información detallada del vehículo en estilo semi-transparente oscuro.
/// 
/// Muestra:
/// - Placa y Modelo
/// - Hora de última actualización
/// - Ubicación (dirección)
/// - Estado (Estático/En Movimiento con tiempo)
/// - Motor (Encendido/Apagado con tiempo)
/// - Batería
/// - Voltaje externo
/// - Kilometraje
/// - Distancia recorrida hoy
class VehicleInfoWindow extends StatefulWidget {
  final DeviceModel device;
  final DateTime lastUpdate;

  const VehicleInfoWindow({
    super.key,
    required this.device,
    required this.lastUpdate,
  });

  @override
  State<VehicleInfoWindow> createState() => _VehicleInfoWindowState();
}

class _VehicleInfoWindowState extends State<VehicleInfoWindow> {
  double? _validSpeed;

  @override
  void initState() {
    super.initState();
    _loadValidData();
  }

  /// Carga velocidad válida usando el endpoint si es necesario
  Future<void> _loadValidData() async {
    final coords = await CoordinateService.getValidCoordinates(
      widget.device.idDispositivo.toString(),
      widget.device.latitude,
      widget.device.longitude,
    );
    
    if (mounted) {
      setState(() {
        _validSpeed = coords['speed'] as double?;
      });
    }
  }

  /// Calcula el tiempo estático (sin movimiento)
  String _getTiempoEstatico() {
    final velocidad = _validSpeed ?? widget.device.speed ?? 0.0;
    if (velocidad < 1.0) {
      // Si la velocidad es menor a 1 km/h, está estático
      final tiempoEstatico = DateTime.now().difference(widget.lastUpdate);
      return _formatDuration(tiempoEstatico);
    }
    return ''; // Si está en movimiento, no mostrar tiempo
  }
  
  /// Obtiene el texto del estado
  String _getEstadoTexto() {
    final velocidad = _validSpeed ?? widget.device.speed ?? 0.0;
    if (velocidad < 1.0) {
      return 'Estático';
    }
    return 'En Movimiento';
  }

  /// Calcula el tiempo del motor apagado/encendido
  String _getEstadoMotor() {
    if (widget.device.estadoMotor == true) {
      final tiempoEncendido = DateTime.now().difference(widget.lastUpdate);
      return 'Encendido(${_formatDuration(tiempoEncendido)})';
    } else if (widget.device.estadoMotor == false) {
      final tiempoApagado = DateTime.now().difference(widget.lastUpdate);
      return 'Apagado(${_formatDuration(tiempoApagado)})';
    }
    return 'Desconocido';
  }

  /// Formatea una duración en formato legible
  String _formatDuration(Duration duration) {
    final horas = duration.inHours;
    final minutos = duration.inMinutes.remainder(60);
    final segundos = duration.inSeconds.remainder(60);
    
    if (horas > 0) {
      return '${horas}h${minutos}min${segundos}s';
    } else if (minutos > 0) {
      return '${minutos}min${segundos}s';
    } else {
      return '${segundos}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoTexto = _getEstadoTexto();
    final tiempoEstatico = _getTiempoEstatico();
    final estadoMotor = _getEstadoMotor();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75), // Semi-transparente oscuro
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placa y Modelo
              Text(
                '${widget.device.placa ?? 'Sin Placa'}(${widget.device.modelo ?? 'FMB920'})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              
              // Hora
              _buildInfoRow('Hora:', DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.lastUpdate)),
              const SizedBox(height: 3),
              
              // Estado
              _buildInfoRow('Estado:', tiempoEstatico.isNotEmpty ? '$estadoTexto($tiempoEstatico)' : estadoTexto),
              const SizedBox(height: 3),
              
              // Motor
              _buildInfoRow('Motor:', estadoMotor),
              const SizedBox(height: 3),
              
              // Batería
              _buildInfoRow('Batería:', widget.device.bateria != null ? '${widget.device.bateria}%' : 'N/A'),
              const SizedBox(height: 3),
              
              // Voltaje externo
              _buildInfoRow('Voltaje externo:', widget.device.voltaje != null ? '${widget.device.voltaje!.toStringAsFixed(1)}V' : 'N/A'),
              const SizedBox(height: 3),
              
              // Hoy (distancia del día - placeholder por ahora)
              _buildInfoRow('Hoy:', '0km'), // TODO: Calcular distancia del día
            ],
          ),
        ),
        // Flecha hacia abajo
        Positioned(
          bottom: -2,
          left: 130, // Centrado para width 280
          child: CustomPaint(
            size: const Size(20, 10),
            painter: _ArrowPainter(),
          ),
        ),
      ],
    );
  }

  /// Construye una fila de información
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.75) // Mismo color que el contenedor
      ..style = PaintingStyle.fill;
    
    // Flecha que se une al contenedor
    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
