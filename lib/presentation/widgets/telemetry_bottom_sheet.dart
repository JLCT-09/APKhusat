import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';

/// Modal inferior que muestra información detallada del vehículo en formato vertical.
/// 
/// Muestra telemetría completa:
/// - Estado (En Movimiento / Detenido)
/// - Velocidad en km/h
/// - Latitud y Longitud con 6 decimales
/// - Hora de última actualización
/// - Botón para ver historial de recorrido
/// 
/// Se abre al presionar un marcador de vehículo en el mapa.
class TelemetryBottomSheet extends StatelessWidget {
  /// Posición del vehículo (latitud, longitud)
  final double latitude;
  final double longitude;
  
  /// Velocidad actual en km/h
  final double speedKmh;
  
  /// Estado del vehículo (En Movimiento / Detenido)
  final String status;
  
  /// Hora de última actualización formateada
  final String time;
  
  /// IMEI del dispositivo para confirmar identidad
  final String? imei;
  
  /// Dispositivo asociado para cargar el historial
  final DeviceModel? device;
  
  /// Callback que se ejecuta cuando se selecciona un rango de fechas para el historial
  /// Recibe el dispositivo y las fechas seleccionadas
  final void Function(DeviceModel device, DateTime fechaDesde, DateTime fechaHasta)? onLoadHistorial;

  const TelemetryBottomSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.status,
    required this.time,
    this.imei,
    this.device,
    this.onLoadHistorial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con icono de vehículo
            Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Información del Vehículo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Sección de Identidad (IMEI e ID)
            _buildIdentitySection(),
            
            // Divider sutil entre identidad y datos de movimiento
            const Divider(height: 40),
            
            // Información de Telemetría con iconos rojos HusatGps
            _buildTelemetrySection(),
            
            // Espacio antes del botón de historial
            const SizedBox(height: 24),
            
            // Botón para consultar historial (solo si hay dispositivo y callback)
            if (device != null && onLoadHistorial != null)
              _buildHistorialButton(context),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  /// Construye la sección de identidad del dispositivo (IMEI e ID)
  Widget _buildIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: IMEI con icono de chip/celular (resaltado)
          if (imei != null && imei!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.sim_card, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'IMEI: $imei',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Fila 2: ID en un Badge/Chip gris claro (discreto)
          if (device != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'ID de Sistema: ${device!.idDispositivo}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  /// Construye la sección de telemetría con iconos rojos HusatGps
  Widget _buildTelemetrySection() {
    return Column(
      children: [
        // Estado
        _buildTelemetryTile(
          icon: Icons.circle,
          label: 'Estado',
          value: status,
          valueColor: status == 'En Movimiento' ? Colors.green : Colors.grey,
        ),
        const Divider(height: 1),
        // Velocidad
        _buildTelemetryTile(
          icon: Icons.speed,
          label: 'Velocidad',
          value: '${speedKmh.toStringAsFixed(1)} km/h',
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Latitud
        _buildTelemetryTile(
          icon: Icons.location_on,
          label: 'Latitud',
          value: latitude.toStringAsFixed(6),
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Longitud
        _buildTelemetryTile(
          icon: Icons.location_on,
          label: 'Longitud',
          value: longitude.toStringAsFixed(6),
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Hora
        _buildTelemetryTile(
          icon: Icons.access_time,
          label: 'Hora',
          value: time,
          valueColor: Colors.black87,
        ),
      ],
    );
  }
  
  /// Construye un ListTile para información de telemetría con icono rojo HusatGps
  Widget _buildTelemetryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      leading: Icon(icon, color: Colors.red, size: 24),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: valueColor,
        ),
      ),
    );
  }
  
  /// Construye el botón de historial al final de la lista
  Widget _buildHistorialButton(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history, color: Colors.red, size: 24),
      title: const Text(
        'Consultar Historial de Recorrido',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () => _openHistorialPicker(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
    );
  }
  
  /// Abre el selector de rango de fechas nativo de Flutter para el historial
  void _openHistorialPicker(BuildContext context) {
    if (device == null || onLoadHistorial == null) return;
    
    // Cerrar el bottom sheet primero
    Navigator.of(context).pop();
    
    // Abrir el selector de rango de fechas nativo con locale español
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.red, // HusatGps red
            colorScheme: const ColorScheme.light(primary: Colors.red),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    ).then((selectedRange) {
      if (selectedRange != null && device != null && onLoadHistorial != null) {
        // Ajustar fechas: desde 00:00:00 y hasta 23:59:59
        final fechaDesde = DateTime(
          selectedRange.start.year,
          selectedRange.start.month,
          selectedRange.start.day,
          0, // 00:00:00
          0,
          0,
        );
        final fechaHasta = DateTime(
          selectedRange.end.year,
          selectedRange.end.month,
          selectedRange.end.day,
          23, // 23:59:59
          59,
          59,
        );
        
        onLoadHistorial!(device!, fechaDesde, fechaHasta);
      }
    });
  }

}
