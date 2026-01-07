import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';

/// Panel inferior fijo con acciones para el vehículo seleccionado.
/// 
/// Muestra:
/// - IMEI centrado y legible
/// - Fila de botones con iconos y labels: Detalle, Seguimiento, Historial, Comando, Navegación, Más
class VehicleActionPanel extends StatelessWidget {
  final DeviceModel device;
  final double latitude;
  final double longitude;
  final VoidCallback onDetalle;
  final VoidCallback onSeguimiento;
  final VoidCallback onHistorial;
  final VoidCallback onComando;
  final VoidCallback onNavegacion;
  final VoidCallback onMas;

  const VehicleActionPanel({
    super.key,
    required this.device,
    required this.latitude,
    required this.longitude,
    required this.onDetalle,
    required this.onSeguimiento,
    required this.onHistorial,
    required this.onComando,
    required this.onNavegacion,
    required this.onMas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de arrastre
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // IMEI centrado
            if (device.imei != null && device.imei!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Text(
                  'IMEI: ${device.imei}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Fila de botones de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.info_outline,
                    label: 'Detalle',
                    onTap: onDetalle,
                  ),
                  _buildActionButton(
                    icon: Icons.my_location,
                    label: 'Seguimiento',
                    onTap: onSeguimiento,
                  ),
                  _buildActionButton(
                    icon: Icons.history,
                    label: 'Historial',
                    onTap: onHistorial,
                  ),
                  _buildActionButton(
                    icon: Icons.settings_remote,
                    label: 'Comando',
                    onTap: onComando,
                  ),
                  _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navegación',
                    onTap: onNavegacion,
                  ),
                  _buildActionButton(
                    icon: Icons.more_vert,
                    label: 'Más',
                    onTap: onMas,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
