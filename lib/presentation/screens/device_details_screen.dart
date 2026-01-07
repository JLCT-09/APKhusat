import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/coordinate_service.dart';
import '../../core/services/share_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadValidCoordinates();
  }

  Future<void> _loadValidCoordinates() async {
    final coords = await CoordinateService.getValidCoordinates(
      widget.device.idDispositivo.toString(),
      widget.device.latitude,
      widget.device.longitude,
    );
    
    if (mounted) {
      setState(() {
        _validLat = coords['latitude'] as double;
        _validLng = coords['longitude'] as double;
        _validSpeed = coords['speed'] as double?;
        _validRumbo = coords['rumbo'] as double?;
        _validTimestamp = coords['timestamp'] as DateTime?;
        _isLoadingCoordinates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _validLat ?? widget.device.latitude;
    final lng = _validLng ?? widget.device.longitude;
    
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
            value: widget.device.imei ?? 'No disponible',
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.credit_card,
            title: 'Tarjeta SIM',
            value: 'SIM Card', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.numbers,
            title: 'ICCID',
            value: 'No disponible', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.confirmation_number,
            title: 'Número de placa',
            value: widget.device.placa ?? 'No disponible',
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.devices,
            title: 'Modelo',
            value: widget.device.modelo ?? 'FMB920',
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.calendar_today,
            title: 'Fecha de activación',
            value: DateFormat('dd/MM/yyyy').format(widget.device.lastUpdate),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.event,
            title: 'Fecha de vencimiento',
            value: 'No disponible', // TODO: Obtener del backend si está disponible
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.circle,
            title: 'Estado',
            value: widget.status,
            valueColor: widget.status == 'En Movimiento' ? Colors.green : Colors.grey,
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.speed,
            title: 'Velocidad',
            value: _isLoadingCoordinates 
                ? 'Cargando...' 
                : '${(_validSpeed ?? widget.speedKmh).toStringAsFixed(1)} km/h',
          ),
          if (_validRumbo != null) ...[
            const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
            _buildDetailTile(
              icon: Icons.explore,
              title: 'Rumbo',
              value: '${_validRumbo!.toStringAsFixed(0)}°',
            ),
          ],
          if (_validTimestamp != null) ...[
            const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
            _buildDetailTile(
              icon: Icons.access_time,
              title: 'Última actualización',
              value: DateFormat('dd/MM/yyyy HH:mm:ss').format(_validTimestamp!),
            ),
          ],
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.location_on,
            title: 'Latitud',
            value: _isLoadingCoordinates 
                ? 'Cargando...' 
                : (lat == 0.0 && lng == 0.0 
                    ? 'No disponible' 
                    : '${lat.toStringAsFixed(6)}'),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.location_on,
            title: 'Longitud',
            value: _isLoadingCoordinates 
                ? 'Cargando...' 
                : (lat == 0.0 && lng == 0.0 
                    ? 'No disponible' 
                    : '${lng.toStringAsFixed(6)}'),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
          _buildDetailTile(
            icon: Icons.power_settings_new,
            title: 'Estado del motor',
            value: widget.device.estadoMotor == true ? 'Encendido' : 'Apagado',
            valueColor: widget.device.estadoMotor == true ? Colors.green : Colors.red,
            ),
          const SizedBox(height: 24),
          // Botón Compartir Ubicación
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final placa = widget.device.placa ?? 'Sin Placa';
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
