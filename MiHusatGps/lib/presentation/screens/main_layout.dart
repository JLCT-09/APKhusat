import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user.dart';
import '../../domain/models/device_model.dart';
import 'map_screen.dart';
import 'devices_screen.dart';
import 'alerts_history_screen.dart';
import 'profile_screen.dart';

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// Layout principal con IndexedStack para navegación instantánea
/// 
/// Mantiene todas las pantallas en memoria para transiciones sin carga
class MainLayout extends StatefulWidget {
  final int initialIndex;
  final int? notificationDeviceId;
  
  const MainLayout({
    super.key,
    this.initialIndex = 0,
    this.notificationDeviceId,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavigationTap(int index) {
    // Si tocan "Alertas" (índice 2), mostrar mensaje placeholder
    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Módulo de Alertas en proceso...'),
          duration: Duration(seconds: 2),
        ),
      );
      return; // No cambiar de pantalla
    }
    
    setState(() {
      _currentIndex = index;
    });
  }
  
  /// Cambia al Monitor y enfoca un dispositivo específico
  void focusDeviceOnMap(DeviceModel device) {
    setState(() {
      _currentIndex = 0; // Cambiar al Monitor (índice 0)
    });
    
    // Esperar un momento para que el IndexedStack cambie, luego enfocar el dispositivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapScreenKey.currentState?.focusDevice(device);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? UserRole.client;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Monitor (Mapa) - Índice 0
          MapScreen(
            key: _mapScreenKey,
            selectedDevice: widget.notificationDeviceId != null
                ? null // Se buscará el dispositivo después
                : null,
          ),
          // Dispositivos - Índice 1
          DevicesScreen(
            key: const ValueKey('devices_screen'),
            onDeviceSelected: focusDeviceOnMap,
          ),
          // Alertas - Índice 2
          AlertsHistoryScreen(
            userRole: userRole,
            key: const ValueKey('alerts_screen'),
          ),
          // Yo (Perfil) - Índice 3
          const ProfileScreen(
            key: ValueKey('profile_screen'),
          ),
        ],
      ),
      // OCULTAR BottomNavigationBar cuando el historial O seguimiento esté activo
      // Usar ValueListenableBuilder anidados para escuchar ambos notifiers
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _mapScreenKey.currentState?.historialStateNotifier ?? ValueNotifier<bool>(false),
        builder: (context, isHistorialActive, child) {
          return ValueListenableBuilder<bool>(
            valueListenable: _mapScreenKey.currentState?.trackingStateNotifier ?? ValueNotifier<bool>(false),
            builder: (context, isTrackingActive, child) {
              // Si el historial O seguimiento está activo, retornar un widget vacío (ocultar barra)
              if (isHistorialActive || isTrackingActive) {
                return const SizedBox.shrink();
              }
              
              // Si no está activo, mostrar la barra de navegación
              return BottomNavigationBar(
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _colorCorporativo,
                unselectedItemColor: Colors.grey[600],
                onTap: _onNavigationTap,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map),
                    label: 'Monitor',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list_alt),
                    label: 'Dispositivos',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications_active),
                    label: 'Alertas',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Yo',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
