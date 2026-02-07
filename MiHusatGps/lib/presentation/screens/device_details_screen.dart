import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/coordinate_service.dart';
import '../../core/services/share_service.dart';
import '../../data/gps_service.dart';

/// Pantalla de detalles del dispositivo GPS.
/// 
/// Muestra información completa del dispositivo en formato de lista:
/// - IMEI, Tarjeta SIM, ICCID, Número de placa
/// - Modelo (FMB920), Fechas de activación/vencimiento
/// - Estado, Velocidad, Coordenadas, Estado del motor
class DeviceDetailsScreen extends StatefulWidget {
  final DeviceModel device;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final String status;

  const DeviceDetailsScreen({
    super.key,
    required this.device,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.status,
  });

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  double? _validLat;
  double? _validLng;
  double? _validSpeed;
  double? _validRumbo;
  DateTime? _validTimestamp;
  bool _isLoadingCoordinates = true;
  
  // Datos de telemetría del endpoint estado-dispositivo
  int? _bateriaGps;
  double? _energiaExterna;
  bool? _encendido;
  double? _odometro;

  @override
  void initState() {
    super.initState();
    _loadEstadoDispositivo();
  }

  /// Carga el estado detallado del dispositivo usando /api/estado-dispositivo/{id}
  Future<void> _loadEstadoDispositivo() async {
    try {
      // OPTIMIZACIÓN: Usar endpoint de telemetría /api/estado-dispositivo/{id}
      final estado = await GpsService.getEstadoDispositivo(widget.device.idDispositivo.toString());
      
      if (estado != null && mounted) {
        setState(() {
          // Mapear campos del endpoint según Swagger
          _bateriaGps = estado['bateria'] as int?;
          _energiaExterna = estado['energiaExterna'] != null 
              ? (estado['energiaExterna'] is num 
                  ? estado['energiaExterna'].toDouble() 
                  : double.tryParse(estado['energiaExterna'].toString()))
              : null;
          _encendido = estado['encendido'] as bool?;
          _odometro = estado['odometro'] != null
              ? (estado['odometro'] is num
                  ? estado['odometro'].toDouble()
                  : double.tryParse(estado['odometro'].toString()))
              : null;
          
          // También actualizar coordenadas si están disponibles
          final lat = estado['latitud'] ?? estado['latitude'];
          final lng = estado['longitud'] ?? estado['longitude'];
          if (lat != null && lng != null) {
            _validLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
            _validLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
          }
          
          // IMPORTANTE: Usar velocidad del dispositivo (que viene del batch en km/h) como fuente principal
          // Solo usar velocidad del endpoint si el dispositivo no tiene velocidad válida
          final speedFromEstado = estado['velocidad'] ?? estado['speed'];
          if (speedFromEstado != null) {
            var speedValue = (speedFromEstado is num) ? speedFromEstado.toDouble() : double.tryParse(speedFromEstado.toString());
            
            // El endpoint /api/estado-dispositivo/{id} puede devolver velocidad en m/s o km/h
            // Si el valor es menor a 50 y mayor a 0, probablemente está en m/s, convertir a km/h
            if (speedValue != null && speedValue < 50 && speedValue > 0) {
              speedValue = speedValue * 3.6; // Convertir m/s a km/h
              debugPrint('🔄 Velocidad del endpoint convertida de m/s a km/h: $speedValue');
            }
            
            // Usar velocidad del endpoint solo si el dispositivo no tiene velocidad válida
            // O si la velocidad del dispositivo es 0 y el endpoint tiene un valor válido
            if (widget.device.speed == 0 || widget.device.speed == null) {
              _validSpeed = speedValue;
            } else {
              // Preferir velocidad del dispositivo (viene del batch y está en km/h)
              _validSpeed = widget.device.speed;
              debugPrint('✅ Usando velocidad del dispositivo: ${_validSpeed} km/h');
            }
          } else {
            // Si no hay velocidad en el endpoint, usar la del dispositivo
            _validSpeed = widget.device.speed;
          }
          
          final rumbo = estado['rumbo'] ?? estado['heading'];
          if (rumbo != null) {
            _validRumbo = (rumbo is num) ? rumbo.toDouble() : double.tryParse(rumbo.toString());
          }
          
          _isLoadingCoordinates = false;
        });
      } else {
        // Fallback: usar método anterior si el endpoint no está disponible
        await _loadValidCoordinates();
      }
    } catch (e) {
      debugPrint('Error al cargar estado del dispositivo: $e');
      // Fallback: usar método anterior
      await _loadValidCoordinates();
    }
  }

  Future<void> _loadValidCoordinates() async {
    try {
      final coords = await CoordinateService.getValidCoordinates(
        widget.device.idDispositivo.toString(),
        widget.device.latitude,
        widget.device.longitude,
      );
      
      if (mounted) {
        setState(() {
          _validLat = coords['latitude'] as double? ?? widget.device.latitude;
          _validLng = coords['longitude'] as double? ?? widget.device.longitude;
          _validSpeed = coords['speed'] as double?;
          _validRumbo = coords['rumbo'] as double?;
          _validTimestamp = coords['timestamp'] as DateTime?;
          _isLoadingCoordinates = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar coordenadas: $e');
      if (mounted) {
        setState(() {
          _validLat = widget.device.latitude;
          _validLng = widget.device.longitude;
          _validSpeed = widget.speedKmh;
          _isLoadingCoordinates = false;
        });
      }
    }
  }

  /// Valida si las coordenadas son válidas
  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  /// Obtiene el estado del dispositivo basado en idEstadoOperativo (igual que VehicleInfoWindow)
  String _getEstadoFromIdOperativo() {
    final idEstado = widget.device.idEstadoOperativo;
    
    switch (idEstado) {
      case 7: // EN MOVIMIENTO
        return 'En Movimiento';
      case 6: // ESTÁTICO
        return 'Estático';
      case 4: // FUERA DE LÍNEA
        return 'Fuera de Línea';
      default:
        // Fallback: usar movimiento si idEstadoOperativo no está disponible
        return (widget.device.movimiento ?? false) ? 'En Movimiento' : 'Estático';
    }
  }

  /// Obtiene el color del estado basado en idEstadoOperativo
  Color _getEstadoColorFromIdOperativo() {
    final idEstado = widget.device.idEstadoOperativo;
    
    switch (idEstado) {
      case 7: // EN MOVIMIENTO
        return const Color(0xFF4CAF50); // Verde
      case 6: // ESTÁTICO
        return const Color(0xFF2196F3); // Azul
      case 4: // FUERA DE LÍNEA
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final lat = _validLat ?? widget.device.latitude;
      final lng = _validLng ?? widget.device.longitude;
      final hasValidCoordinates = _isValidCoordinate(lat, lng);
      
      // Valores por defecto para campos nulos
      final placa = widget.device.placa ?? 'Sin Placa';
      final bateria = widget.device.bateria ?? 0;
      final modeloGps = widget.device.modeloGps ?? 'FMB920';
      final imei = widget.device.imei ?? 'No disponible';
      
      return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Detalles del Dispositivo'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDetailTile(
              icon: Icons.sim_card,
              title: 'IMEI',
              value: imei.isNotEmpty && imei != 'No disponible' ? imei : 'No disponible',
            ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.credit_card,
            title: 'Tarjeta SIM',
            value: 'SIM Card', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.numbers,
            title: 'ICCID',
            value: 'No disponible', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            _buildDetailTile(
              icon: Icons.confirmation_number,
              title: 'Número de placa',
              value: placa.isNotEmpty && placa != 'Sin Placa' ? placa : 'No disponible',
            ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            _buildDetailTile(
              icon: Icons.devices,
              title: 'Modelo',
              value: modeloGps,
            ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.calendar_today,
            title: 'Fecha de activación',
            value: DateFormat('dd/MM/yyyy').format(widget.device.lastUpdate),
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.event,
            title: 'Fecha de vencimiento',
            value: 'No disponible', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.circle,
            title: 'Estado',
            value: _getEstadoFromIdOperativo(),
            valueColor: _getEstadoColorFromIdOperativo(),
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          _buildDetailTile(
            icon: Icons.speed,
            title: 'Velocidad',
            value: _isLoadingCoordinates 
                ? 'Cargando...' 
                : '${(_validSpeed ?? widget.speedKmh).toStringAsFixed(1)} km/h',
          ),
          if (_validRumbo != null) ...[
            const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            _buildDetailTile(
              icon: Icons.explore,
              title: 'Rumbo',
              value: '${_validRumbo!.toStringAsFixed(0)}°',
            ),
          ],
          if (_validTimestamp != null) ...[
            const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            _buildDetailTile(
              icon: Icons.access_time,
              title: 'Última actualización',
              value: DateFormat('dd/MM/yyyy HH:mm:ss').format(_validTimestamp!),
            ),
          ],
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            if (!hasValidCoordinates) ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este dispositivo aún no ha reportado coordenadas GPS',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildDetailTile(
                icon: Icons.location_on,
                title: 'Latitud',
                value: _isLoadingCoordinates 
                    ? 'Cargando...' 
                    : '${lat.toStringAsFixed(6)}',
              ),
              const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
              _buildDetailTile(
                icon: Icons.location_on,
                title: 'Longitud',
                value: _isLoadingCoordinates 
                    ? 'Cargando...' 
                    : '${lng.toStringAsFixed(6)}',
              ),
            ],
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          // Batería GPS (del endpoint estado-dispositivo)
          if (_bateriaGps != null) ...[
            _buildDetailTile(
              icon: Icons.battery_std,
              title: 'Batería GPS',
              value: '$_bateriaGps%',
              valueColor: _bateriaGps! > 20 ? Colors.green : Colors.red,
            ),
            const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          ],
          // Energía Externa / Alimentación (del endpoint estado-dispositivo)
          if (_energiaExterna != null) ...[
            _buildDetailTile(
              icon: Icons.power,
              title: 'Alimentación',
              value: '${_energiaExterna!.toStringAsFixed(2)}V',
              valueColor: Colors.blue,
            ),
            const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
          ],
          // Estado del Motor / Encendido (del endpoint estado-dispositivo)
          _buildDetailTile(
            icon: Icons.power_settings_new,
            title: 'Motor',
            value: (_encendido ?? widget.device.estadoMotor ?? false) ? 'Encendido' : 'Apagado',
            valueColor: (_encendido ?? widget.device.estadoMotor ?? false) ? Colors.green : Colors.red,
          ),
          // Odómetro (del endpoint estado-dispositivo)
          if (_odometro != null) ...[
            const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20), // Aumentado de 0.5 a 0.8
            _buildDetailTile(
              icon: Icons.speed,
              title: 'Odómetro',
              value: '${_odometro!.toStringAsFixed(2)} km',
              valueColor: Colors.blue,
            ),
          ],
          const SizedBox(height: 24),
          // Botón Compartir Ubicación (solo si hay coordenadas válidas)
          if (hasValidCoordinates)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ShareService().shareLocation(
                    placa: placa,
                    latitude: lat,
                    longitude: lng,
                  );
                },
              icon: const Icon(Icons.share, size: 20),
              label: const Text(
                'Compartir Ubicación',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), // Rojo corporativo
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
    } catch (e) {
      debugPrint('❌ Error en build de DeviceDetailsScreen: $e');
      // Widget de error seguro
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Detalles del Dispositivo'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar los detalles del dispositivo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor, intenta nuevamente',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.red, size: 18),
          const SizedBox(width: 16),
          SizedBox(
            width: 120, // Ancho fijo para labels - alineación estricta
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
