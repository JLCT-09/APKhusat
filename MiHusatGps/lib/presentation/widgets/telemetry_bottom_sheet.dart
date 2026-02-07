import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// Modal inferior que muestra información del vehículo en formato vertical.
/// 
/// Muestra solo:
/// - Placa
/// - Modelo GPS
/// - Batería
/// - Energía Externa
/// - Botón para ver historial de recorrido
/// 
/// Se abre al presionar un marcador de vehículo en el mapa.
class TelemetryBottomSheet extends StatelessWidget {
  /// Dispositivo asociado para mostrar información y cargar el historial
  final DeviceModel? device;
  
  /// Callback que se ejecuta cuando se selecciona un rango de fechas para el historial
  /// Recibe el dispositivo y las fechas seleccionadas
  final void Function(DeviceModel device, DateTime fechaDesde, DateTime fechaHasta)? onLoadHistorial;

  const TelemetryBottomSheet({
    super.key,
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
                const Icon(Icons.directions_car, color: _colorCorporativo, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Información del Vehículo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _colorCorporativo,
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
            
            // Información del Vehículo: Placa, Modelo, Batería, Energía Externa
            _buildVehicleInfoSection(),
            
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
  
  /// Construye la sección de información del vehículo
  Widget _buildVehicleInfoSection() {
    return Column(
      children: [
        // Placa
        _buildTelemetryTile(
          icon: Icons.confirmation_number,
          label: 'Placa',
          value: device?.placa ?? 'Sin Placa',
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Modelo GPS
        _buildTelemetryTile(
          icon: Icons.devices,
          label: 'Modelo GPS',
          value: device?.modelo ?? 'FMB920',
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Batería
        _buildTelemetryTile(
          icon: Icons.battery_std,
          label: 'Batería',
          value: device?.bateria != null ? '${device!.bateria}%' : '0%',
          valueColor: Colors.black87,
        ),
        const Divider(height: 1),
        // Energía Externa
        _buildTelemetryTile(
          icon: Icons.power,
          label: 'Energía Externa',
          value: device?.voltajeExterno != null ? '${device!.voltajeExterno!.toStringAsFixed(2)}V' : '0.00V',
          valueColor: Colors.black87,
        ),
      ],
    );
  }
  
  /// Construye un ListTile para información de telemetría con icono corporativo HusatGps
  Widget _buildTelemetryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      leading: Icon(icon, color: _colorCorporativo, size: 24),
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
      leading: const Icon(Icons.history, color: _colorCorporativo, size: 24),
      title: const Text(
        'Consultar Historial de Recorrido',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _colorCorporativo,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () => _openHistorialPicker(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _colorCorporativo.withOpacity(0.3), width: 1),
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
            primaryColor: _colorCorporativo, // Color corporativo HusatGps
            colorScheme: const ColorScheme.light(primary: _colorCorporativo),
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
