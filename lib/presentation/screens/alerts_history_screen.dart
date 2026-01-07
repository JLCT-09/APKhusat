import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/models/alert_model.dart';
import '../../core/services/alert_storage_service.dart';
import '../../core/services/navigation_service.dart';
import '../../domain/models/user.dart';
import 'map_screen.dart';
import '../../data/device_service.dart';
import '../../domain/models/device_model.dart';

/// Pantalla de historial de alertas.
/// 
/// Muestra todas las alertas recibidas con:
/// - Tipo (Exceso velocidad/Sin señal)
/// - Placa del vehículo
/// - Fecha/Hora
/// - Icono representativo
/// - Indicador de no leída
class AlertsHistoryScreen extends StatefulWidget {
  final UserRole userRole;

  const AlertsHistoryScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  List<AlertModel> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    final alerts = await AlertStorageService().getAllAlerts();
    
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  Future<void> _navigateToAlertLocation(AlertModel alert) async {
    if (alert.latitude == null || alert.longitude == null) {
      // Si no hay coordenadas, intentar obtenerlas del dispositivo
      try {
        final devices = await DeviceService.getDispositivosPorUsuario('6'); // TODO: Obtener del usuario logueado
        final device = devices.firstWhere(
          (d) => d.idDispositivo.toString() == alert.deviceId,
          orElse: () => devices.first,
        );
        
        // Marcar alerta como leída
        await AlertStorageService().markAsRead(alert.id);
        
        // Navegar al mapa con el dispositivo seleccionado
        final navigator = NavigationService().navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => MapScreen(
                userRole: widget.userRole,
                selectedDevice: device,
                centerOnDevice: true,
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar la ubicación del vehículo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Marcar alerta como leída
      await AlertStorageService().markAsRead(alert.id);
      
      // Navegar al mapa usando la ruta nombrada con deviceId
      final navigator = NavigationService().navigatorKey.currentState;
      if (navigator != null) {
        // Usar la misma lógica robusta: navegar a /monitor con deviceId
        navigator.pushNamed('/monitor', arguments: alert.deviceId);
      }
    }
    
    // Recargar alertas para actualizar estado de leída
    _loadAlerts();
  }

  Future<void> _markAllAsRead() async {
    await AlertStorageService().markAllAsRead();
    _loadAlerts();
  }

  Future<void> _clearAllAlerts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas las alertas'),
        content: const Text('¿Estás seguro de que deseas eliminar todas las alertas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AlertStorageService().clearAllAlerts();
      _loadAlerts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Historial de Alertas'),
        backgroundColor: const Color(0xFFD32F2F), // Rojo corporativo
        foregroundColor: Colors.white,
        actions: [
          if (_alerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
          if (_alerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar todas',
              onPressed: _clearAllAlerts,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay alertas',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _alerts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      return _buildAlertItem(alert);
                    },
                  ),
                ),
    );
  }

  Widget _buildAlertItem(AlertModel alert) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isUnread = !alert.isRead;

    return InkWell(
      onTap: () => _navigateToAlertLocation(alert),
      child: Container(
        color: isUnread ? Colors.grey[50] : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Indicador de no leída
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F), // Rojo corporativo
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 20),
            
            // Icono de la alerta
            Text(
              alert.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        dateFormat.format(alert.timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.placa,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFD32F2F), // Rojo corporativo
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Icono de navegación
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
