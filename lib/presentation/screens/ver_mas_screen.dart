import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/share_service.dart';
import 'device_details_screen.dart';

/// Pantalla "Ver Más" con opciones adicionales para el dispositivo.
/// 
/// Muestra:
/// - Cabecera con IMEI e ID del dispositivo
/// - Fila de acciones principales (Detalle, Seguimiento, Historial, Comando)
/// - Lista de opciones adicionales (Historial, Compartir Ubicación)
class VerMasScreen extends StatelessWidget {
  final DeviceModel device;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final String status;
  final VoidCallback? onSeguimiento;
  final VoidCallback? onHistorial;
  final VoidCallback? onComando;

  const VerMasScreen({
    super.key,
    required this.device,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.status,
    this.onSeguimiento,
    this.onHistorial,
    this.onComando,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver Más'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Cabecera con IMEI e ID
          _buildHeader(),
          
          // Fila de acciones principales
          _buildActionButtons(context),
          
          const Divider(height: 1, thickness: 0.5),
          
          // Lista de opciones
          Expanded(
            child: _buildOptionsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sim_card, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'IMEI: ${device.imei ?? 'No disponible'}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Separador visual
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // ID en la misma fila
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tag, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  'ID: ${device.idDispositivo}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.info_outline,
              label: 'Detalle',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeviceDetailsScreen(
                      device: device,
                      latitude: latitude,
                      longitude: longitude,
                      speedKmh: speedKmh,
                      status: status,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.my_location,
              label: 'Seguimiento',
              onTap: () {
                Navigator.of(context).pop();
                onSeguimiento?.call();
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.history,
              label: 'Historial',
              onTap: () {
                Navigator.of(context).pop();
                onHistorial?.call();
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.settings_remote,
              label: 'Comando',
              onTap: () {
                Navigator.of(context).pop();
                onComando?.call();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          leading: const Icon(Icons.history, color: Colors.red, size: 24),
          title: Text(
            'Historial',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            Navigator.of(context).pop();
            onHistorial?.call();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        const Divider(height: 1, thickness: 0.5),
        ListTile(
          leading: const Icon(Icons.share, color: Colors.red, size: 24),
          title: Text(
            'Compartir Ubicación',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            _shareLocation(context);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ],
    );
  }

  Future<void> _shareLocation(BuildContext context) async {
    final placa = device.placa ?? 'Sin Placa';
    await ShareService().shareLocation(
      placa: placa,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
