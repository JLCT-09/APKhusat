import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/alert_model.dart';
import '../../core/services/alert_storage_service.dart';
import '../../core/services/navigation_service.dart';
import '../../domain/models/user.dart';
import '../../data/device_service.dart';
import '../../domain/models/device_model.dart';

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

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
  List<AlertModel> _filteredAlerts = [];
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
    
    // Filtrar alertas únicas: solo una por tipo y placa (la más reciente)
    final Map<String, AlertModel> uniqueAlerts = {};
    for (final alert in alerts) {
      final key = '${alert.type}_${alert.placa}';
      if (!uniqueAlerts.containsKey(key) || 
          alert.timestamp.isAfter(uniqueAlerts[key]!.timestamp)) {
        uniqueAlerts[key] = alert;
      }
    }
    
    // Ordenar por fecha más reciente primero
    final sortedAlerts = uniqueAlerts.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    setState(() {
      _alerts = alerts;
      _filteredAlerts = sortedAlerts;
      _isLoading = false;
    });
  }
  
  /// Obtiene el modelo GPS desde la placa o deviceId
  Future<String?> _getModeloGps(AlertModel alert) async {
    try {
      final devices = await DeviceService.getDispositivosPorUsuario('6'); // TODO: Obtener del usuario logueado
      if (devices.isEmpty) {
        return 'FMB920';
      }
      
      DeviceModel? device;
      try {
        device = devices.firstWhere(
          (d) => d.idDispositivo.toString() == alert.deviceId || d.placa == alert.placa,
        );
      } catch (e) {
        // Si no encuentra, usar el primero disponible
        device = devices.first;
      }
      
      return device?.modeloGps ?? 'FMB920';
    } catch (e) {
      return 'FMB920';
    }
  }
  
  /// Obtiene el tipo de alerta formateado
  String _getTipoAlerta(AlertModel alert) {
    if (alert.type == 'speed') {
      return 'Exceso de velocidad';
    } else if (alert.type == 'coverage') {
      return 'Desconexión';
    }
    return alert.title;
  }

  Future<void> _navigateToAlertLocation(AlertModel alert) async {
    // Marcar alerta como leída si no está leída
    if (!alert.isRead) {
      await AlertStorageService().markAsRead(alert.id);
      _loadAlerts();
    }
    
    // Navegar al Monitor (índice 0) usando la ruta nombrada con deviceId
    final navigator = NavigationService().navigatorKey.currentState;
    if (navigator != null) {
      // Navegar a /monitor con deviceId para que MainLayout lo maneje
      navigator.pushNamed('/monitor', arguments: alert.deviceId);
    }
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
        title: const Text('Alertas'),
        backgroundColor: _colorCorporativo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Eliminar botón de regreso
        actions: [
          if (_filteredAlerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
          if (_filteredAlerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar todas',
              onPressed: _clearAllAlerts,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredAlerts.isEmpty
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
                        style: TextStyle(
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
                    padding: EdgeInsets.zero,
                    itemCount: _filteredAlerts.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.8, // Aumentado de 0.5 a 0.8
                      color: Colors.grey[300],
                    ),
                    itemBuilder: (context, index) {
                      final alert = _filteredAlerts[index];
                      // OPTIMIZACIÓN: Animación de entrada suave para cada alerta
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)), // Deslizamiento desde abajo
                              child: child,
                            ),
                          );
                        },
                        child: _buildAlertItem(alert),
                      );
                    },
                  ),
                ),
      // BottomNavigationBar ahora se maneja desde MainLayout
    );
  }

  Widget _buildAlertItem(AlertModel alert) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yy');
    final isUnread = !alert.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), // Animación suave al cambiar estado
      color: isUnread 
        ? _colorCorporativo.withOpacity(0.05) // Fondo rojo muy sutil para no leídas
        : Colors.white,
      child: InkWell(
        onTap: () async {
          // Marcar como leída al presionar
          if (isUnread) {
            await AlertStorageService().markAsRead(alert.id);
            _loadAlerts();
          }
          _navigateToAlertLocation(alert);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Aumentado de 12 a 16
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna 1: Logo/Icono (diferente según tipo de alerta)
            Icon(
              alert.type == 'speed' ? Icons.speed : Icons.signal_wifi_off,
              color: _colorCorporativo,
              size: 28, // Aumentado de 24 a 28
            ),
            const SizedBox(width: 12),
            
            // Columna 2: Información Principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila 1: Placa | Modelo GPS (en Negrita y letra pequeña)
                  FutureBuilder<String?>(
                    future: _getModeloGps(alert),
                    builder: (context, snapshot) {
                      final modeloGps = snapshot.data ?? 'FMB920';
                      return RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15, // Aumentado de 13 a 15
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          children: [
                            TextSpan(text: alert.placa),
                            TextSpan(
                              text: ' | $modeloGps',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // Fila 2: Tipo de Alerta
                  Text(
                    _getTipoAlerta(alert),
                    style: TextStyle(
                      fontSize: 13, // Aumentado de 12 a 13
                      fontWeight: FontWeight.w500, // Agregado peso medio
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            
            // Columna 3: Tiempo (Alineado a la derecha)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Fila 1: Hora
                Text(
                  timeFormat.format(alert.timestamp),
                  style: TextStyle(
                    fontSize: 13, // Aumentado de 12 a 13
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4), // Aumentado de 2 a 4
                // Fila 2: Fecha
                Text(
                  dateFormat.format(alert.timestamp),
                  style: TextStyle(
                    fontSize: 12, // Aumentado de 11 a 12
                    color: Colors.grey[600],
                  ),
                ),
                // Indicador de no leída
                if (isUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colorCorporativo,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
