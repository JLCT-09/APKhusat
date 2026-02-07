import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:location/location.dart' as loc;
import 'package:url_launcher/url_launcher.dart';

// Models & Core
import '../../domain/models/device_model.dart';
import '../../domain/models/location_point.dart';
import '../../domain/models/user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/supervision_filter_provider.dart';
import '../../data/gps_service.dart';
import '../../data/user_service.dart';
import '../../core/config/app_config.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/storage_service.dart';

// Managers (La nueva lógica modular)
import '../managers/marker_manager.dart';
import '../managers/device_update_manager.dart';
import '../managers/history_manager.dart';

// Widgets
import '../widgets/historial_controls_overlay.dart';
import '../widgets/glass_action_bar.dart';
import '../widgets/vehicle_info_window.dart';
import '../widgets/tracking_info_window.dart';
import '../widgets/historial_dialog.dart';
import '../widgets/address_bar.dart';
import '../widgets/dialogs/vehicle_command_dialog.dart';
import '../widgets/device_search_delegate.dart';
import '../../core/utils/navigation_launcher.dart';
import 'device_details_screen.dart';
import 'ver_mas_screen.dart';

class MapScreen extends StatefulWidget {
  final DeviceModel? selectedDevice;
  final UserRole? userRole;
  final int? notificationDeviceId;

  const MapScreen({
    Key? key,
    this.selectedDevice,
    this.userRole,
    this.notificationDeviceId,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // --- 1. Managers (Cerebros de la operación) ---
  late final MarkerManager _markerManager;
  late final DeviceUpdateManager _deviceUpdateManager;
  final HistoryManager _historyManager = HistoryManager();

  // --- 2. Controladores de Mapa ---
  GoogleMapController? _mapController;
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  final loc.Location _location = loc.Location();

  // --- 3. Estado de Datos ---
  List<DeviceModel> _devices = [];
  bool _isLoadingDevices = false;

  // --- 4. Estado Visual (Optimizado) ---
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier({});
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {}; // Para el historial

  // --- 5. Selección y UI ---
  DeviceModel? _selectedDevice;
  bool _showInfoWindow = false;
  bool _showActionBar = false;

  // --- 6. Historial ---
  bool _isShowingHistorial = false;
  List<GpsLocation> _playbackHistory = [];
  double _playbackSliderValue = 0.0;
  double _playbackSpeed = 1.0;
  
  // --- 7. Modo Seguimiento ---
  bool _isTrackingMode = false;
  DeviceModel? _trackedDevice; // Dispositivo que se está siguiendo
  List<LatLng> _trackingPath = []; // Lista de puntos para la polyline verde
  
  // --- 8. Estado de UI adicional ---
  bool _showSuccessMessage = false; // Para mensaje flotante de actualización
  bool _trafficEnabled = false; // Estado de capa de tráfico
  
  // --- 9. Filtro de Supervisión (Solo Admins) ---
  int? _usuarioFiltroId; // ID del usuario objetivo para filtro de supervisión
  String? _usuarioFiltroNombre; // Nombre del usuario objetivo para mostrar en el banner
  
  // Notifier para notificar cambios en el estado del historial (para MainLayout)
  final ValueNotifier<bool> _historialStateNotifier = ValueNotifier<bool>(false);
  
  // Notifier para notificar cambios en el estado del seguimiento (para MainLayout)
  final ValueNotifier<bool> _trackingStateNotifier = ValueNotifier<bool>(false);
  
  // OPTIMIZACIÓN: ValueNotifier para el contador (evita rebuilds innecesarios)
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(10);
  
  // Getter público para verificar estado del historial
  bool get isShowingHistorial => _isShowingHistorial;
  
  // Getter para el notifier del historial (para MainLayout)
  ValueNotifier<bool> get historialStateNotifier => _historialStateNotifier;
  
  // Getter para el notifier del seguimiento (para MainLayout)
  ValueNotifier<bool> get trackingStateNotifier => _trackingStateNotifier;

  @override
  void initState() {
    super.initState();

    // A. Inicializar Managers
    _markerManager = MarkerManager();
    
    // Inicializar devicePixelRatio para cálculo adaptativo de tamaños de iconos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        MarkerManager.setDevicePixelRatio(mediaQuery.devicePixelRatio);
        debugPrint('📱 DevicePixelRatio inicializado: ${mediaQuery.devicePixelRatio}');
      }
    });

    _deviceUpdateManager = DeviceUpdateManager();
    _deviceUpdateManager.onAutoRefreshTriggered = () async {
      // OPTIMIZACIÓN: Manejo de errores mejorado
      try {
        // Cuando el contador llega a 0, ejecutar actualización automática
        if (!mounted || _isShowingHistorial) return;
        
        // Si estamos en modo seguimiento, actualizar solo el dispositivo seguido
        if (_isTrackingMode && _trackedDevice != null) {
          await _updateTrackingDevice();
          // Reiniciar el contador para seguimiento
          if (mounted && _isTrackingMode) {
            _deviceUpdateManager.startUpdateCounter();
          }
          return;
        }
        // Si hay un filtro activo, recargar dispositivos del usuario objetivo
        if (_usuarioFiltroId != null) {
          final refreshedDevices = await _deviceUpdateManager.performManualRefresh(
            _devices,
            usuarioIdObjetivo: _usuarioFiltroId,
          );
          await _handleAutoRefresh(refreshedDevices);
        } else {
          final updatedDevices = await _deviceUpdateManager.performAutoRefresh(_devices);
          await _handleAutoRefresh(updatedDevices);
        }
        // Reiniciar el contador después de la actualización
        if (mounted && !_isShowingHistorial && !_isTrackingMode) {
          _deviceUpdateManager.startUpdateCounter();
        }
      } catch (e) {
        debugPrint('❌ Error en auto-refresh: $e');
        // Reiniciar contador incluso si hay error para mantener ciclo activo
        if (mounted && !_isShowingHistorial && !_isTrackingMode) {
          _deviceUpdateManager.startUpdateCounter();
        }
      }
    };
    // OPTIMIZACIÓN: Usar ValueNotifier en lugar de setState para el contador
    _deviceUpdateManager.onCountdownChanged = (seconds) {
      if (mounted) {
        _countdownNotifier.value = seconds; // No causa rebuild completo del widget
      }
    };

    // B. Escuchar cambios en el filtro de supervisión (sincronización con DevicesScreen)
    // OPTIMIZACIÓN: Esperar un frame adicional para asegurar que el widget esté completamente montado
    // y que cualquier animación de transición haya comenzado antes de cargar datos pesados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Esperar un pequeño delay para que la transición de navegación se complete
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        
        final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
        _usuarioFiltroId = filterProvider.usuarioFiltroId;
        _usuarioFiltroNombre = filterProvider.usuarioFiltroNombre;
        
        // Escuchar cambios en el filtro para sincronizar cuando se cambia desde DevicesScreen
        filterProvider.addListener(_onSupervisionFilterChanged);
        
        // Carga Inicial
        _loadInitialData();
        
        // Si hay un deviceId de notificación, enfocarlo después de cargar
        if (widget.notificationDeviceId != null) {
          _handleNotificationDevice(widget.notificationDeviceId!);
        }
      });
    });
  }

  /// Callback cuando cambia el filtro de supervisión desde DevicesScreen
  void _onSupervisionFilterChanged() {
    if (!mounted) return;
    
    final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
    final nuevoUsuarioId = filterProvider.usuarioFiltroId;
    final nuevoNombre = filterProvider.usuarioFiltroNombre;
    
    // Solo recargar si el filtro cambió (evitar loop infinito)
    if (_usuarioFiltroId != nuevoUsuarioId) {
      _aplicarFiltroUsuario(nuevoUsuarioId, nuevoNombre, updateProvider: false);
    }
  }

  @override
  void dispose() {
    // Remover listener del filtro de supervisión
    try {
      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
      filterProvider.removeListener(_onSupervisionFilterChanged);
    } catch (e) {
      debugPrint('⚠️ Error al remover listener del filtro: $e');
    }
    
    // Limpiar managers primero
    _deviceUpdateManager.dispose();
    _historyManager.dispose();
    
    // BLINDAJE: Limpiar InfoWindow con try-catch para evitar crashes
    try {
      _customInfoWindowController.hideInfoWindow?.call();
    } catch (e) {
      debugPrint('⚠️ Error al ocultar InfoWindow en dispose: $e');
    }
    
    // BLINDAJE: Dispose del controller con protección
    try {
      _customInfoWindowController.dispose();
    } catch (e) {
      debugPrint('⚠️ Error al hacer dispose del InfoWindowController: $e');
    }
    
    // Limpiar notifiers y controladores
    _markersNotifier.dispose();
    _historialStateNotifier.dispose();
    _trackingStateNotifier.dispose();
    _countdownNotifier.dispose(); // OPTIMIZACIÓN: Limpiar ValueNotifier del contador
    _mapController?.dispose();
    
    super.dispose();
  }

  // ==========================================
  // 1. GESTIÓN DE DATOS Y CARGA
  // ==========================================

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    // OPTIMIZACIÓN: Mostrar loading solo una vez al inicio
    if (mounted) {
      setState(() => _isLoadingDevices = true);
    }

    try {
      // OPTIMIZACIÓN: Paralelizar permisos de ubicación con carga de dispositivos
      // Los permisos no son críticos para mostrar dispositivos, pueden ejecutarse en paralelo
      final permissionsFuture = _checkLocationPermissions().catchError((e) {
        debugPrint('⚠️ Error al verificar permisos: $e');
      });

      // Cargar Dispositivos (Usamos el manager manual para la primera carga)
      debugPrint('🔄 _loadInitialData: Cargando dispositivos (PARALELIZADO)...');
      final devicesFuture = _deviceUpdateManager.performManualRefresh(
        _devices,
        usuarioIdObjetivo: _usuarioFiltroId,
      );

      // Esperar ambos en paralelo, pero priorizar dispositivos
      final results = await Future.wait([
        permissionsFuture,
        devicesFuture,
      ]);
      
      final updatedDevices = results[1] as List<DeviceModel>;
      debugPrint('✅ _loadInitialData: Cargados ${updatedDevices.length} dispositivos');
      
      if (!mounted) return;
      
      // OPTIMIZACIÓN: Consolidar todo en un solo setState para evitar múltiples rebuilds
      // Esto mejora la fluidez al reducir el número de reconstrucciones del widget
      setState(() {
        _devices = updatedDevices;
        _isLoadingDevices = false;
      });
      
      // OPTIMIZACIÓN: Cargar marcadores de forma asíncrona y progresiva
      // Usar microtask para no bloquear el hilo principal
      Future.microtask(() async {
        if (!mounted) return;
        
        debugPrint('🔄 _loadInitialData: Creando marcadores de forma asíncrona...');
        await _refreshMarkers(); // Dibujar flota inicial
        
        if (!mounted) return;
        
        // OPTIMIZACIÓN: Mostrar dispositivos después de crear marcadores
        if (_mapController != null && _devices.isNotEmpty) {
          // Usar addPostFrameCallback para mejor sincronización con el frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mapController != null) {
              _showAllDevicesOnMap();
            }
          });
        }
      });
      
      // OPTIMIZACIÓN: Actualizar estados operativos en segundo plano (no bloquea la UI)
      // Esto permite que los dispositivos se muestren primero con datos básicos
      // y luego se actualicen los estados operativos sin bloquear la carga inicial
      _updateEstadosOperativosInBackground(updatedDevices);

      // 3. Iniciar el ciclo automático de 10s (después de mostrar dispositivos)
      _deviceUpdateManager.startUpdateCounter();

      // 4. Si venimos de la lista con un dispositivo seleccionado, enfocarlo
      if (widget.selectedDevice != null && mounted) {
        // Esperar un frame para que los marcadores se hayan creado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              final target = _devices.firstWhere(
                (d) => d.idDispositivo == widget.selectedDevice!.idDispositivo,
                orElse: () => widget.selectedDevice!,
              );
              _selectDevice(target);
            } catch (e) {
              debugPrint('⚠️ Error al seleccionar dispositivo inicial: $e');
            }
          }
        });
      }

    } catch (e) {
      debugPrint('❌ Error en carga inicial: $e');
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  /// Se ejecuta automáticamente cada 10 segundos
  Future<void> _handleAutoRefresh(List<DeviceModel> updatedDevices) async {
    if (!mounted || _isShowingHistorial) return;
    
    // Si estamos en modo seguimiento, manejar actualización especial
    if (_isTrackingMode && _trackedDevice != null) {
      await _handleTrackingRefresh(updatedDevices);
      return;
    }

    debugPrint('🔄 [Auto] Iniciando actualización automática con ${updatedDevices.length} dispositivos');
    
    // Verificar cambios de coordenadas antes de actualizar estados operativos
    for (var updatedDevice in updatedDevices) {
      final oldDevice = _devices.firstWhere(
        (d) => d.idDispositivo == updatedDevice.idDispositivo,
        orElse: () => updatedDevice,
      );
      
      if (oldDevice.latitude != updatedDevice.latitude || oldDevice.longitude != updatedDevice.longitude) {
        debugPrint('📍 [Auto] Coordenadas cambiaron para dispositivo ${updatedDevice.idDispositivo}: (${oldDevice.latitude}, ${oldDevice.longitude}) → (${updatedDevice.latitude}, ${updatedDevice.longitude})');
      }
    }

    // Obtener estados operativos para todos los dispositivos en paralelo
    // CRÍTICO: _updateEstadosOperativos preserva las coordenadas de /api/estado-dispositivo/{id}
    final devicesWithEstado = await _updateEstadosOperativos(updatedDevices);

    // Verificar si el dispositivo seleccionado cambió su idEstadoOperativo
    final selectedDeviceId = _selectedDevice?.idDispositivo;
    DeviceModel? updatedSelectedDevice;
    
    if (selectedDeviceId != null) {
      updatedSelectedDevice = devicesWithEstado.firstWhere(
        (d) => d.idDispositivo == selectedDeviceId,
        orElse: () => _selectedDevice!,
      );
      
      // Si cambió el idEstadoOperativo, actualizar el dispositivo seleccionado
      if (updatedSelectedDevice.idEstadoOperativo != _selectedDevice?.idEstadoOperativo) {
        debugPrint('🔄 [Auto] idEstadoOperativo cambió para dispositivo $selectedDeviceId: ${_selectedDevice?.idEstadoOperativo} → ${updatedSelectedDevice.idEstadoOperativo}');
        setState(() {
          _selectedDevice = updatedSelectedDevice;
        });
        
        // Regenerar marcador del dispositivo seleccionado inmediatamente
        if (updatedSelectedDevice.latitude != 0 && updatedSelectedDevice.longitude != 0) {
          final position = LatLng(updatedSelectedDevice.latitude, updatedSelectedDevice.longitude);
          final newMarker = await _markerManager.createMarkerForDevice(
            device: updatedSelectedDevice,
            position: position,
            onTap: () => _selectDevice(updatedSelectedDevice!),
          );
          
          if (mounted) {
            setState(() {
              _markers.removeWhere((m) => m.markerId.value == 'device_$selectedDeviceId');
              _markers.add(newMarker);
              _markersNotifier.value = Set.from(_markers);
            });
          }
        }
      }
    }

    // CRÍTICO: Actualizar _devices con las coordenadas del batch antes de refrescar marcadores
    setState(() {
      _devices = devicesWithEstado;
    });

    debugPrint('🔄 [Auto] Actualizando marcadores con nuevas coordenadas...');
    // Actualizar marcadores (colores Verde/Azul/Plomo según idEstadoOperativo y nuevas coordenadas)
    await _refreshMarkers();
    debugPrint('✅ [Auto] Actualización automática completada');
  }
  
  /// Actualiza los estados operativos en segundo plano (no bloquea la UI)
  /// 
  /// Se ejecuta después de mostrar los dispositivos iniciales para mejorar la percepción de velocidad
  Future<void> _updateEstadosOperativosInBackground(List<DeviceModel> devices) async {
    if (devices.isEmpty || !mounted) return;
    
    // Ejecutar en segundo plano sin bloquear
    Future.microtask(() async {
      try {
        debugPrint('🔄 [Background] Actualizando estados operativos en segundo plano para ${devices.length} dispositivos...');
        final updatedDevices = await _updateEstadosOperativos(devices);
        
        if (!mounted) return;
        
        // Solo actualizar si hay cambios en idEstadoOperativo
        bool hasChanges = false;
        for (int i = 0; i < updatedDevices.length && i < _devices.length; i++) {
          if (updatedDevices[i].idEstadoOperativo != _devices[i].idEstadoOperativo) {
            hasChanges = true;
            break;
          }
        }
        
        if (hasChanges) {
          setState(() {
            _devices = updatedDevices;
          });
          
          // Refrescar marcadores para actualizar colores (Verde/Azul/Plomo)
          await _refreshMarkers();
          debugPrint('✅ [Background] Estados operativos actualizados en segundo plano');
        }
      } catch (e) {
        debugPrint('⚠️ [Background] Error al actualizar estados operativos: $e');
      }
    });
  }

  /// Actualiza los estados operativos de todos los dispositivos usando el endpoint /api/estado-dispositivo/{id}/estado
  /// 
  /// IMPORTANTE: Preserva las coordenadas y otros datos del batch, solo actualiza idEstadoOperativo
  /// Usa Future.wait para hacer las llamadas en paralelo y no bloquear la UI
  Future<List<DeviceModel>> _updateEstadosOperativos(List<DeviceModel> devices) async {
    if (devices.isEmpty) return devices;
    
    try {
      // Crear lista de futures para ejecutar en paralelo
      final futures = devices.map((device) async {
        try {
          // Llamar al endpoint para obtener idEstadoOperativo
          final estadoOperativo = await GpsService.getEstadoOperativoDispositivo(device.idDispositivo.toString());
          
          if (estadoOperativo != null && estadoOperativo['idEstadoOperativo'] != null) {
            final idEstadoOperativo = estadoOperativo['idEstadoOperativo'] is int
                ? estadoOperativo['idEstadoOperativo'] as int
                : int.tryParse(estadoOperativo['idEstadoOperativo'].toString());
            
            if (idEstadoOperativo != null) {
              // CRÍTICO: Preservar TODAS las coordenadas y datos del batch
              // Solo actualizar idEstadoOperativo y codigoEstadoOperativo
              return DeviceModel(
                idDispositivo: device.idDispositivo,
                nombre: device.nombre,
                imei: device.imei,
                placa: device.placa,
                usuarioId: device.usuarioId,
                nombreUsuario: device.nombreUsuario,
                status: device.status,
                latitude: device.latitude, // PRESERVAR coordenadas del batch
                longitude: device.longitude, // PRESERVAR coordenadas del batch
                speed: device.speed, // PRESERVAR velocidad del batch
                lastUpdate: device.lastUpdate,
                voltaje: device.voltaje,
                voltajeExterno: device.voltajeExterno,
                kilometrajeTotal: device.kilometrajeTotal,
                bateria: device.bateria,
                estadoMotor: device.estadoMotor,
                movimiento: device.movimiento, // PRESERVAR movimiento del batch
                rumbo: device.rumbo, // PRESERVAR rumbo del batch
                modeloGps: device.modeloGps,
                tipo: device.tipo,
                fechaVencimiento: device.fechaVencimiento,
                idEstado: device.idEstado,
                codigoEstadoOperativo: estadoOperativo['codigoEstadoOperativo']?.toString() ?? device.codigoEstadoOperativo,
                idEstadoOperativo: idEstadoOperativo, // ACTUALIZADO desde el endpoint
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error al obtener estado operativo para dispositivo ${device.idDispositivo}: $e');
        }
        
        // Si falla, retornar el dispositivo original (con coordenadas preservadas)
        return device;
      }).toList();
      
      // Ejecutar todas las llamadas en paralelo
      final updatedDevices = await Future.wait(futures);
      debugPrint('✅ Estados operativos actualizados para ${updatedDevices.length} dispositivos (coordenadas preservadas)');
      return updatedDevices;
    } catch (e) {
      debugPrint('❌ Error al actualizar estados operativos: $e');
      return devices;
    }
  }

  /// Se ejecuta al presionar el botón flotante
  void _handleManualRefreshButton() async {
    // No hacer nada si estamos en modo seguimiento
    if (_isTrackingMode) return;
    // Obtener estados operativos para todos los dispositivos en paralelo
    final updatedDevices = await _updateEstadosOperativos(_devices);
    
    if (!mounted) return;
    
    // Verificar si el dispositivo seleccionado cambió su idEstadoOperativo
    final selectedDeviceId = _selectedDevice?.idDispositivo;
    DeviceModel? updatedSelectedDevice;
    
    if (selectedDeviceId != null) {
      updatedSelectedDevice = updatedDevices.firstWhere(
        (d) => d.idDispositivo == selectedDeviceId,
        orElse: () => _selectedDevice!,
      );
      
      // Si cambió el idEstadoOperativo, actualizar el dispositivo seleccionado y regenerar marcador
      if (updatedSelectedDevice.idEstadoOperativo != _selectedDevice?.idEstadoOperativo) {
        debugPrint('🔄 [Manual] idEstadoOperativo cambió para dispositivo $selectedDeviceId: ${_selectedDevice?.idEstadoOperativo} → ${updatedSelectedDevice.idEstadoOperativo}');
        setState(() {
          _selectedDevice = updatedSelectedDevice;
        });
        
        // Regenerar marcador del dispositivo seleccionado inmediatamente
        if (updatedSelectedDevice.latitude != 0 && updatedSelectedDevice.longitude != 0) {
          final position = LatLng(updatedSelectedDevice.latitude, updatedSelectedDevice.longitude);
          final newMarker = await _markerManager.createMarkerForDevice(
            device: updatedSelectedDevice,
            position: position,
            onTap: () => _selectDevice(updatedSelectedDevice!),
          );
          
          if (mounted) {
            setState(() {
              _markers.removeWhere((m) => m.markerId.value == 'device_$selectedDeviceId');
              _markers.add(newMarker);
              _markersNotifier.value = Set.from(_markers);
            });
          }
        }
      }
    }
    
    setState(() {
      _devices = updatedDevices;
    });
    
    // CRÍTICO: No refrescar marcadores si estamos en modo historial (solo mostrar dispositivo del historial)
    if (!_isShowingHistorial) {
      _refreshMarkers();
    }
    
    // Reiniciar el contador explícitamente (ValueNotifier se actualiza automáticamente)
    _deviceUpdateManager.resetUpdateCounter();

    // Mostrar mensaje flotante superior en lugar de SnackBar
    if (mounted) {
      setState(() {
        _showSuccessMessage = true;
      });
      
      // Ocultar el mensaje después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSuccessMessage = false;
          });
        }
      });
    }
  }

  // ==========================================
  // 2. GESTIÓN DE MARCADORES (Delegada)
  // ==========================================

  Future<void> _refreshMarkers() async {
    if (_isShowingHistorial || _isTrackingMode) return;

    debugPrint('🔄 _refreshMarkers: Iniciando con ${_devices.length} dispositivos');
    
    // Verificar cambios de coordenadas antes de crear marcadores
    for (var device in _devices) {
      final existingMarker = _markers.firstWhere(
        (m) => m.markerId.value == 'device_${device.idDispositivo}',
        orElse: () => Marker(markerId: MarkerId('none'), position: LatLng(0, 0)),
      );
      
      if (existingMarker.markerId.value != 'none') {
        final oldPosition = existingMarker.position;
        final newPosition = LatLng(device.latitude, device.longitude);
        
        if (oldPosition.latitude != newPosition.latitude || oldPosition.longitude != newPosition.longitude) {
          debugPrint('📍 [Refresh] Coordenadas cambiaron para dispositivo ${device.idDispositivo}: (${oldPosition.latitude}, ${oldPosition.longitude}) → (${newPosition.latitude}, ${newPosition.longitude})');
        }
      }
    }
    
    // El MarkerManager se encarga de la lógica de Verde/Azul/Plomo y Rotación
    final newMarkers = await _markerManager.createMarkersForDevices(
      devices: _devices,
      onDeviceTap: (deviceId, device, position) {
        _selectDevice(device);
      },
      getDevicePosition: (device) async {
        // CRÍTICO: Usar siempre las coordenadas del dispositivo (ya actualizadas del batch)
        if (device.latitude != 0 && device.longitude != 0) {
          debugPrint('✅ [Refresh] Usando coordenadas del dispositivo ${device.idDispositivo}: ${device.latitude}, ${device.longitude}');
          return LatLng(device.latitude, device.longitude);
        }
        
        // Intentar obtener desde última ubicación solo si las coordenadas son inválidas
        debugPrint('⚠️ [Refresh] Coordenadas inválidas para dispositivo ${device.idDispositivo}, intentando obtener desde última ubicación...');
        try {
          final ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
          if (ultimaUbicacion != null && ultimaUbicacion.isDataAvailable) {
            final position = ultimaUbicacion.toLatLng();
            debugPrint('✅ [Refresh] Obtenida última ubicación para dispositivo ${device.idDispositivo}: ${position.latitude}, ${position.longitude}');
            return position;
          } else {
            debugPrint('❌ [Refresh] Última ubicación no disponible para dispositivo ${device.idDispositivo}');
          }
        } catch (e) {
          debugPrint('❌ [Refresh] Error al obtener última ubicación para dispositivo ${device.idDispositivo}: $e');
        }
        debugPrint('❌ [Refresh] No se pudo obtener posición para dispositivo ${device.idDispositivo}');
        return null;
      },
    );

    debugPrint('✅ _refreshMarkers: Creados ${newMarkers.length} marcadores de ${_devices.length} dispositivos');

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _markersNotifier.value = Set.from(_markers);
      });
      debugPrint('✅ [Refresh] Marcadores actualizados en el mapa: ${_markers.length}');
      
      // Verificar que los marcadores tienen las coordenadas correctas
      for (var marker in _markers) {
        final deviceIdStr = marker.markerId.value.replaceFirst('device_', '');
        final deviceId = int.tryParse(deviceIdStr);
        if (deviceId != null) {
          try {
            final device = _devices.firstWhere(
              (d) => d.idDispositivo == deviceId,
            );
            if (device.latitude != 0 && device.longitude != 0) {
              debugPrint('✅ [Refresh] Marcador ${deviceId} en posición: (${marker.position.latitude}, ${marker.position.longitude})');
            }
          } catch (e) {
            // Dispositivo no encontrado, ignorar
            debugPrint('⚠️ [Refresh] Dispositivo ${deviceId} no encontrado en la lista');
          }
        }
      }
    } else {
      debugPrint('⚠️ Widget no montado, no se actualizaron los marcadores');
    }
  }

  // ==========================================
  // 3. MODO SEGUIMIENTO
  // ==========================================

  /// Inicia el modo seguimiento para un dispositivo
  Future<void> _startTracking(DeviceModel device) async {
    if (!mounted) return;
    
    // Detener actualización automática de todos los dispositivos
    _deviceUpdateManager.stopUpdateCounter();
    
    // Limpiar marcadores y polylines existentes
    setState(() {
      _isTrackingMode = true;
      _trackedDevice = device;
      _trackingPath = [];
      _markers.clear();
      _polylines.clear();
      _showActionBar = false;
      _showInfoWindow = true;
    });
    
    // Notificar a MainLayout que el seguimiento está activo
    _trackingStateNotifier.value = true;
    
    // Crear marcador solo para el dispositivo seguido
    if (device.latitude != 0 && device.longitude != 0) {
      final position = LatLng(device.latitude, device.longitude);
      _trackingPath.add(position); // Agregar punto inicial
      
      final marker = await _markerManager.createMarkerForDevice(
        device: device,
        position: position,
        onTap: () {}, // No hacer nada al tocar en modo seguimiento
      );
      
      if (mounted) {
        setState(() {
          _markers.add(marker);
          _markersNotifier.value = Set.from(_markers);
        });
      }
      
      // Mostrar InfoWindow de seguimiento
      _customInfoWindowController.addInfoWindow?.call(
        TrackingInfoWindow(device: device),
        position,
      );
      
      // Enfocar cámara en el dispositivo
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 17),
        );
      }
    }
    
    // Iniciar actualización específica para seguimiento
    _deviceUpdateManager.startUpdateCounter();
  }

  /// Detiene el modo seguimiento
  void _stopTracking() {
    if (!mounted) return;
    
    // Detener contador
    _deviceUpdateManager.stopUpdateCounter();
    
    // Notificar a MainLayout que el seguimiento se cerró
    _trackingStateNotifier.value = false;
    
    // Limpiar estado de seguimiento
    setState(() {
      _isTrackingMode = false;
      _trackedDevice = null;
      _trackingPath = [];
      _polylines.clear();
      _showInfoWindow = false;
      _showActionBar = false;
      _selectedDevice = null;
    });
    
    // Ocultar InfoWindow
    _customInfoWindowController.hideInfoWindow?.call();
    
    // Limpiar marcadores
    _markers.clear();
    _markersNotifier.value = {};
    
    // Refrescar todos los marcadores y reiniciar contador normal
    _refreshMarkers();
    _deviceUpdateManager.startUpdateCounter();
    
    // Mostrar todos los dispositivos en el mapa
    if (_mapController != null && _devices.isNotEmpty) {
      _showAllDevicesOnMap();
    }
  }

  /// Actualiza el dispositivo en modo seguimiento
  Future<void> _updateTrackingDevice() async {
    if (!mounted || _trackedDevice == null) return;
    
    try {
      // Obtener estado actualizado del dispositivo
      final estado = await GpsService.getEstadoDispositivo(_trackedDevice!.idDispositivo.toString());
      if (estado == null) return;
      
      // Obtener estado operativo
      final estadoOperativo = await GpsService.getEstadoOperativoDispositivo(_trackedDevice!.idDispositivo.toString());
      
      // Crear dispositivo actualizado
      final updatedDevice = DeviceModel.fromJson(estado);
      
      // Actualizar idEstadoOperativo si está disponible
      DeviceModel finalDevice = updatedDevice;
      if (estadoOperativo != null && estadoOperativo['idEstadoOperativo'] != null) {
        final idEstadoOperativo = estadoOperativo['idEstadoOperativo'] is int
            ? estadoOperativo['idEstadoOperativo'] as int
            : int.tryParse(estadoOperativo['idEstadoOperativo'].toString());
        
        if (idEstadoOperativo != null) {
          finalDevice = DeviceModel(
            idDispositivo: updatedDevice.idDispositivo,
            nombre: updatedDevice.nombre,
            imei: updatedDevice.imei,
            placa: updatedDevice.placa,
            usuarioId: updatedDevice.usuarioId,
            nombreUsuario: updatedDevice.nombreUsuario,
            status: updatedDevice.status,
            latitude: updatedDevice.latitude,
            longitude: updatedDevice.longitude,
            speed: updatedDevice.speed,
            lastUpdate: updatedDevice.lastUpdate,
            voltaje: updatedDevice.voltaje,
            voltajeExterno: updatedDevice.voltajeExterno,
            kilometrajeTotal: updatedDevice.kilometrajeTotal,
            bateria: updatedDevice.bateria,
            estadoMotor: updatedDevice.estadoMotor,
            movimiento: updatedDevice.movimiento,
            rumbo: updatedDevice.rumbo,
            modeloGps: updatedDevice.modeloGps,
            tipo: updatedDevice.tipo,
            fechaVencimiento: updatedDevice.fechaVencimiento,
            idEstado: updatedDevice.idEstado,
            codigoEstadoOperativo: estadoOperativo['codigoEstadoOperativo']?.toString(),
            idEstadoOperativo: idEstadoOperativo,
          );
        }
      }
      
      if (!mounted) return;
      
      // Actualizar dispositivo seguido
      setState(() {
        _trackedDevice = finalDevice;
      });
      
      // Agregar punto a la ruta si cambió de posición
      if (finalDevice.latitude != 0 && finalDevice.longitude != 0) {
        final newPosition = LatLng(finalDevice.latitude, finalDevice.longitude);
        
        // Solo agregar si es diferente al último punto (evitar duplicados)
        if (_trackingPath.isEmpty || 
            (_trackingPath.last.latitude != newPosition.latitude || 
             _trackingPath.last.longitude != newPosition.longitude)) {
          setState(() {
            _trackingPath.add(newPosition);
            
            // Crear polyline verde con ancho adaptativo
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('tracking_path'),
                points: List.from(_trackingPath),
                color: Colors.green,
                width: 8, // Ancho de la línea verde (se puede ajustar según necesidad)
                patterns: [],
              ),
            );
          });
        }
        
        // Actualizar marcador
        final marker = await _markerManager.createMarkerForDevice(
          device: finalDevice,
          position: newPosition,
          onTap: () {},
        );
        
        if (mounted) {
          setState(() {
            _markers.clear();
            _markers.add(marker);
            _markersNotifier.value = Set.from(_markers);
          });
        }
        
        // Actualizar InfoWindow
        _customInfoWindowController.addInfoWindow?.call(
          TrackingInfoWindow(device: finalDevice),
          newPosition,
        );
        
        // Mover cámara para seguir el vehículo
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLng(newPosition),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar dispositivo en seguimiento: $e');
    }
  }

  /// Maneja la actualización automática cuando está en modo seguimiento
  Future<void> _handleTrackingRefresh(List<DeviceModel> updatedDevices) async {
    if (!mounted || _trackedDevice == null) return;
    
    // Actualizar directamente el dispositivo seguido
    await _updateTrackingDevice();
  }

  // ==========================================
  // 4. SELECCIÓN DE VEHÍCULO
  // ==========================================

  void _selectDevice(DeviceModel device) {
    setState(() {
      _selectedDevice = device;
      _showInfoWindow = true;
      _showActionBar = true;
    });

    // Mover cámara
    if (_mapController != null && device.latitude != 0) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(device.latitude, device.longitude),
        16,
      ));
    }

    // Mostrar InfoWindow
    _customInfoWindowController.addInfoWindow?.call(
      VehicleInfoWindow(
        device: device,
        lastUpdate: device.lastUpdate,
      ),
      LatLng(device.latitude, device.longitude),
    );
  }

  void _deselectDevice() {
    setState(() {
      _selectedDevice = null;
      _showInfoWindow = false;
      _showActionBar = false;
    });
    _customInfoWindowController.hideInfoWindow?.call();
  }

  /// Muestra todos los dispositivos visibles en el mapa (zoom out)
  Future<void> _showAllDevicesOnMap() async {
    if (_mapController == null || _devices.isEmpty) return;
    
    // Filtrar dispositivos con coordenadas válidas
    final validDevices = _devices.where((d) => 
      d.latitude != 0 && d.longitude != 0
    ).toList();
    
    if (validDevices.isEmpty) return;
    
    // Calcular bounds para incluir todos los dispositivos
    double minLat = validDevices.first.latitude;
    double maxLat = validDevices.first.latitude;
    double minLng = validDevices.first.longitude;
    double maxLng = validDevices.first.longitude;
    
    for (var device in validDevices) {
      if (device.latitude < minLat) minLat = device.latitude;
      if (device.latitude > maxLat) maxLat = device.latitude;
      if (device.longitude < minLng) minLng = device.longitude;
      if (device.longitude > maxLng) maxLng = device.longitude;
    }
    
    // Crear LatLngBounds
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    // Animar cámara para mostrar todos los dispositivos con padding
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px de padding
    );
  }

  /// Obtiene la ubicación del usuario y centra el mapa
  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    
    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(locationData.latitude!, locationData.longitude!),
            16,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al obtener ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // 4. HISTORIAL (Delegado a HistoryManager)
  // ==========================================

  void _toggleHistorialMode() async {
    if (_selectedDevice == null) return;

    if (_isShowingHistorial) {
      _closeHistory();
    } else {
      // ABRIR DIÁLOGO DE FECHAS
      await showDialog(
        context: context,
        builder: (_) => HistorialDialog(
          device: _selectedDevice!,
          onConfirm: (fechaDesde, fechaHasta, velocidadReproduccion) async {
            // 1. Pausar monitor en vivo
            _deviceUpdateManager.stopUpdateCounter();
            setState(() => _isLoadingDevices = true);

            // 2. Cargar datos con HistoryManager
            final result = await _historyManager.loadHistorial(
              _selectedDevice!,
              fechaDesde,
              fechaHasta,
            );

            if (!mounted) return;

            if (!result.success) {
              setState(() => _isLoadingDevices = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? 'Error al cargar el historial'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // 3. Configurar velocidad de reproducción
            _playbackSpeed = velocidadReproduccion;
            _historyManager.setPlaybackSpeed(velocidadReproduccion);

            // 4. CRÍTICO: Limpiar TODOS los marcadores ANTES de actualizar UI (evitar que aparezcan otros dispositivos)
            _markers.clear();
            _markersNotifier.value = <Marker>{};

            // 5. Actualizar UI
            setState(() {
              _isShowingHistorial = true;
              _isLoadingDevices = false;
              
              // Notificar a MainLayout que el historial está activo
              _historialStateNotifier.value = true;
              
              // Crear polyline del historial (AZUL)
              _polylines.clear();
              if (_historyManager.historialSegments.isNotEmpty) {
                for (int i = 0; i < _historyManager.historialSegments.length; i++) {
                  _polylines.add(
                    Polyline(
                      polylineId: PolylineId('history_route_$i'),
                      points: _historyManager.historialSegments[i],
                      color: Colors.blue, // Cambiado de verde a azul
                      width: 4,
                    ),
                  );
                }
              }
              
              // Ocultar InfoWindow al entrar al historial
              _customInfoWindowController.hideInfoWindow?.call();
            });

            // 6. Crear marcador inicial del dispositivo seleccionado en la primera posición del historial
            // IMPORTANTE: Usar el rumbo del vehículo para rotar el icono y visualizar la dirección
            if (_historyManager.playbackHistory.isNotEmpty && _selectedDevice != null) {
              final primeraUbicacion = _historyManager.playbackHistory.first;
              final primeraPosicion = primeraUbicacion.toLatLng();
              // Obtener rumbo del vehículo (heading en grados 0-360) para visualizar dirección inicial
              final rumboInicial = primeraUbicacion.rumbo ?? 0.0;
              
              // Crear marcador inicial con rotación según rumbo del vehículo
              final markerInicial = await _createPlaybackMarker(primeraPosicion, rumboInicial);
              
              if (mounted) {
                setState(() {
                  _markers.clear(); // Asegurar que solo esté este marcador
                  _markers.add(markerInicial);
                  _markersNotifier.value = Set.from(_markers);
                });
                debugPrint('✅ Marcador inicial del historial creado en posición ${primeraPosicion.latitude}, ${primeraPosicion.longitude}');
              }
            }

            // 7. Ajustar cámara al bounds del historial
            final bounds = _historyManager.getHistorialBounds();
            if (bounds != null && _mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 100),
              );
            }

            // 8. CRÍTICO: Iniciar playback automáticamente después de cargar el historial
            if (_historyManager.playbackHistory.isNotEmpty && _selectedDevice != null && mounted) {
              debugPrint('▶️ Iniciando playback automático del historial...');
              _historyManager.startPlayback(
                device: _selectedDevice!,
                playbackSpeed: _playbackSpeed,
                onLocationUpdate: _handleHistoryLocationUpdate,
                onComplete: _handleHistoryComplete,
              );
              setState(() {}); // Actualizar UI para mostrar que está reproduciendo
            }
          },
        ),
      );
    }
  }

  void _closeHistory() {
    // BLINDAJE: Verificar que el widget esté montado antes de hacer cualquier cosa
    if (!mounted) return;
    
    // Detener y limpiar el historial
    _historyManager.stopPlayback();
    _historyManager.clear();

    // BLINDAJE: Ocultar InfoWindow con try-catch silencioso para evitar crashes
    try {
      if (mounted) {
        _customInfoWindowController.hideInfoWindow?.call();
      }
    } catch (e) {
      // Silenciar errores si el controller ya se cerró
      debugPrint('⚠️ InfoWindow ya estaba cerrado: $e');
    }

    // BLINDAJE: Solo hacer setState si el widget sigue montado
    if (!mounted) return;
    
    setState(() {
      _isShowingHistorial = false;
      _playbackHistory = [];
      _polylines.clear();
      _showActionBar = false;
      _showInfoWindow = false;
      _selectedDevice = null; // Deseleccionar al salir
      
      // CRÍTICO: Limpiar el marcador del historial al salir
      _markers.clear();
      _markersNotifier.value = <Marker>{};
      
      // Notificar a MainLayout que el historial se cerró
      _historialStateNotifier.value = false;
    });

    // BLINDAJE: Verificar mounted antes de reactivar actualización
    if (!mounted) return;
    
    // Reactivar actualización de flota
    _refreshMarkers();
    _deviceUpdateManager.startUpdateCounter();
  }

  /// Callback cuando el historial actualiza la ubicación durante la reproducción
  /// 
  /// IMPORTANTE: Usa el rumbo del vehículo (location.rumbo) para rotar el icono y visualizar
  /// correctamente la dirección hacia donde se dirige el vehículo en cada punto del historial.
  void _handleHistoryLocationUpdate(GpsLocation location, int index) {
    if (!mounted || _selectedDevice == null) return;

    final position = location.toLatLng();
    
    // Obtener rumbo del vehículo (heading en grados 0-360) para visualizar dirección
    // Si no está disponible, calcular desde el punto anterior o usar 0.0 como valor por defecto
    double rumbo = location.rumbo ?? 0.0;
    
    // Si el rumbo no está disponible, intentar calcularlo desde el punto anterior
    if (rumbo == 0.0 && index > 0 && _historyManager.playbackHistory.length > index - 1) {
      final prevLocation = _historyManager.playbackHistory[index - 1];
      final prevPosition = prevLocation.toLatLng();
      
      // Calcular rumbo desde el punto anterior al actual
      final bearing = _calculateBearing(prevPosition, position);
      rumbo = bearing;
      debugPrint('🧭 Rumbo calculado desde punto anterior: $rumbo°');
    }
    
    debugPrint('🧭 Historial - Índice $index: Rumbo = $rumbo°, Posición = (${position.latitude}, ${position.longitude})');
    
    // Crear marcador del playback con icono VERDE y rotación según rumbo
    _createPlaybackMarker(position, rumbo).then((marker) {
      if (!mounted) return;
      setState(() {
        // CRÍTICO: Limpiar TODOS los marcadores y dejar solo el del historial
        _markers.clear();
        _markers.add(marker);
        _markersNotifier.value = Set.from(_markers);
        debugPrint('✅ Marcador del historial actualizado con rumbo $rumbo°: ${_markers.length} marcador(es) en el mapa');
      });
    });

    // Mover cámara al punto actual
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(position),
      );
    }

    // Actualizar slider value
    setState(() {
      _playbackSliderValue = _historyManager.getSliderValue();
    });
    
    // NO mostrar InfoWindow en modo historial
    // (Ya está desactivado, pero por seguridad lo confirmamos)
  }
  
  /// Crea un marcador especial para el playback del historial
  /// Siempre usa el icono VERDE con un tamaño más grande para mejor visibilidad
  /// 
  /// IMPORTANTE: Usa el rumbo (heading) del vehículo para rotar el icono y visualizar
  /// correctamente la dirección hacia donde se dirige el vehículo en cada punto del historial.
  /// El rumbo viene en grados (0-360) desde el backend y se aplica tanto al icono como al Marker.
  Future<Marker> _createPlaybackMarker(LatLng position, double heading) async {
    // Asegurar que el heading esté en el rango 0-360
    final normalizedHeading = heading % 360;
    
    debugPrint('🎯 Creando marcador de playback: Posición = (${position.latitude}, ${position.longitude}), Rumbo = $normalizedHeading°');
    
    // Usar siempre el icono verde para el playback (tamaño más grande: 150px para mejor visibilidad)
    // El rumbo se usa para rotar el icono y mostrar la dirección del vehículo
    final icon = await IconHelper.loadPngFromAsset(
      'assets/images/carro_verde.png',
      size: 150, // Tamaño más grande que el monitor (135px) para mejor visibilidad en historial
      rotation: normalizedHeading, // Rotar icono según rumbo del vehículo (0-360 grados)
    );
    
    return Marker(
      markerId: MarkerId('device_${_selectedDevice!.idDispositivo}'),
      position: position,
      icon: icon,
      rotation: normalizedHeading, // Rotar marcador según rumbo del vehículo para visualizar dirección
      anchor: const Offset(0.5, 0.5),
      flat: true, // Marcador plano que rota con el mapa
      onTap: () {
        // No hacer nada al tocar en modo historial (InfoWindow desactivado)
      },
    );
  }
  
  /// Calcula el rumbo (bearing) entre dos puntos en grados (0-360)
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * (math.pi / 180);
    final lat2 = to.latitude * (math.pi / 180);
    final dLon = (to.longitude - from.longitude) * (math.pi / 180);
    
    final y = math.sin(dLon);
    final x = math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(dLon);
    
    var bearing = math.atan2(y, x) * (180 / math.pi);
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }

  /// Callback cuando el historial termina de reproducirse
  void _handleHistoryComplete() {
    if (!mounted) return;
    
    // Asegurar que el playback se detiene correctamente
    _historyManager.stopPlayback();
    
    // CRÍTICO: Asegurar que el historialStateNotifier se mantenga en true mientras _isShowingHistorial sea true
    // Esto evita que aparezcan los botones de navegación cuando termina la reproducción
    if (_isShowingHistorial) {
      _historialStateNotifier.value = true;
    }
    
    // Actualizar UI sin mostrar ningún mensaje de error
    setState(() {
      // El playback se detiene automáticamente, solo actualizar el estado
    });
    
    // Mostrar mensaje de éxito de forma segura
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reproducción del historial completada'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Silenciar errores si el contexto ya no es válido
      debugPrint('⚠️ No se pudo mostrar mensaje de finalización: $e');
    }
  }

  // ==========================================
  // 5. UTILIDADES Y PERMISOS
  // ==========================================

  /// Abre WhatsApp con el número de soporte de Husat365
  /// 
  /// Intenta abrir la aplicación nativa de WhatsApp primero.
  /// Si no está instalada, abre la versión web como fallback.
  Future<void> _abrirWhatsAppSoporte() async {
    try {
      // Número de soporte de Perú
      const numeroSoporte = '51972496654';
      const mensajePredeterminado = 'Hola soporte Husat365, necesito ayuda con mi servicio.';
      
      // Construir URI de WhatsApp
      final uri = Uri.parse('https://wa.me/$numeroSoporte?text=${Uri.encodeComponent(mensajePredeterminado)}');
      
      debugPrint('📱 Intentando abrir WhatsApp: $uri');
      
      // Verificar si se puede abrir la URL
      if (await canLaunchUrl(uri)) {
        // Intentar abrir la aplicación nativa primero
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          debugPrint('✅ WhatsApp abierto exitosamente');
        } else {
          debugPrint('⚠️ No se pudo abrir WhatsApp');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo abrir WhatsApp. Por favor, instálalo desde la Play Store.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ No se puede abrir WhatsApp');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede abrir WhatsApp. Por favor, instálalo desde la Play Store.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al abrir WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir WhatsApp: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }
  }

  // Método público para llamar desde MainLayout
  void focusDevice(DeviceModel device) {
    // Buscar el dispositivo actualizado en la lista
    try {
      final target = _devices.firstWhere((d) => d.idDispositivo == device.idDispositivo);
      _selectDevice(target);
    } catch (e) {
      // Si no está en la lista, usar el que pasaron
      _selectDevice(device);
    }
  }
  
  /// Maneja el dispositivo desde una notificación
  Future<void> _handleNotificationDevice(int deviceId) async {
    try {
      // Esperar a que se carguen los dispositivos
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Buscar el dispositivo en la lista actual
      final device = _devices.firstWhere(
        (d) => d.idDispositivo == deviceId,
        orElse: () => throw Exception('Device not found'),
      );
      
      // Enfocar el dispositivo
      _selectDevice(device);
    } catch (e) {
      debugPrint('⚠️ No se pudo encontrar el dispositivo $deviceId de la notificación: $e');
    }
  }

  /// Muestra el modal de selección de usuarios para filtro de supervisión
  Future<void> _showUsuarioSelectionModal() async {
    if (!mounted) return;

    // Verificar que el usuario es admin (rolId == 1)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRolId = authProvider.user?.rolId;
    
    // Si el User no tiene rolId, intentar obtenerlo desde StorageService
    int? rolId = userRolId;
    if (rolId == null) {
      rolId = await StorageService.getUserRolId();
    }
    
    if (rolId != 1) {
      debugPrint('❌ Acceso denegado: Solo usuarios con rolId == 1 (Admin) pueden acceder al filtro de supervisión. RolId actual: $rolId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo administradores pueden acceder a esta función'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      // Cargar lista de usuarios
      final usuarios = await UserService.listarUsuarios();
      
      // Ordenar usuarios alfabéticamente por nombreCompleto
      usuarios.sort((a, b) {
        final nombreA = a.nombreCompleto.isNotEmpty ? a.nombreCompleto : a.nombreUsuario;
        final nombreB = b.nombreCompleto.isNotEmpty ? b.nombreCompleto : b.nombreUsuario;
        return nombreA.compareTo(nombreB);
      });
      
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.5, // OPTIMIZACIÓN: Reducido de 0.7 a 0.5
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF1A2D),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Filtro de Supervisión',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Lista de usuarios (sin botón "Ver Mis Dispositivos" - la flecha de regresar ya lo hace)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Lista de usuarios (ordenada alfabéticamente)
                    ...usuarios.map((usuario) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEF1A2D).withOpacity(0.1),
                        radius: 24,
                        child: Text(
                          usuario.nombreCompleto.isNotEmpty
                              ? usuario.nombreCompleto[0].toUpperCase()
                              : usuario.nombreUsuario.isNotEmpty
                                  ? usuario.nombreUsuario[0].toUpperCase()
                                  : 'U',
                          style: const TextStyle(
                            color: Color(0xFFEF1A2D),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        usuario.nombreCompleto.isNotEmpty
                            ? usuario.nombreCompleto
                            : usuario.nombreUsuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: usuario.email.isNotEmpty
                          ? Text(
                              usuario.email,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            )
                          : null,
                      trailing: _usuarioFiltroId == usuario.id
                          ? const Icon(Icons.check_circle, color: Color(0xFFEF1A2D), size: 24)
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        // CRÍTICO: Limpiar dispositivos ANTES de aplicar el filtro para evitar confusión
                        setState(() {
                          _devices = []; // Limpiar inmediatamente
                          _markers = {}; // Limpiar marcadores
                          _markersNotifier.value = {}; // Limpiar notifier
                          _isLoadingDevices = true; // Mostrar loading
                        });
                        _aplicarFiltroUsuario(
                          usuario.id,
                          usuario.nombreCompleto.isNotEmpty
                              ? usuario.nombreCompleto
                              : usuario.nombreUsuario,
                        );
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error al cargar usuarios: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuarios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Aplica el filtro de usuario y recarga los dispositivos
  Future<void> _aplicarFiltroUsuario(int? usuarioId, String? nombreUsuario, {bool updateProvider = true}) async {
    if (!mounted) return;

    // CRÍTICO: Limpiar dispositivos INMEDIATAMENTE para cambio rápido
    setState(() {
      _devices = []; // Limpiar lista antes de cargar
      _markers = {}; // Limpiar marcadores
      _markersNotifier.value = {}; // Limpiar notifier
      _usuarioFiltroId = usuarioId;
      _usuarioFiltroNombre = nombreUsuario;
      _isLoadingDevices = true;
    });

    // Actualizar Provider para sincronizar con DevicesScreen (solo si no viene del listener)
    if (updateProvider) {
      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
      filterProvider.setFiltroUsuario(usuarioId, nombreUsuario);
    }

    try {
      // Recargar dispositivos con el filtro aplicado
      final updatedDevices = await _deviceUpdateManager.performManualRefresh(
        [],
        usuarioIdObjetivo: usuarioId,
      );

      if (mounted) {
        setState(() {
          _devices = updatedDevices;
          _isLoadingDevices = false;
        });
        
        // Refrescar marcadores
        _refreshMarkers();
        
        // OPTIMIZACIÓN: Mostrar dispositivos inmediatamente usando addPostFrameCallback
        if (_mapController != null && _devices.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mapController != null) {
              _showAllDevicesOnMap();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error al aplicar filtro de usuario: $e');
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar dispositivos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================
  // 6. INTERFAZ (BUILD)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Verificar si el usuario es admin (rolId == 1)
    // Primero intentar desde el User, si no está disponible, consultar StorageService
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRolId = authProvider.user?.rolId;
    // Si el User no tiene rolId, se verificará dinámicamente cuando se presione el botón
    final isAdmin = userRolId == 1; // Solo rolId == 1 es admin

    return Scaffold(
      // OCULTAR AppBar durante el historial para evitar el cuadro rojo
      appBar: _isShowingHistorial 
          ? null 
          : AppBar(
              backgroundColor: const Color(0xFFEF1A2D), // Rojo corporativo
              centerTitle: true,
              elevation: 0,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              leading: _isTrackingMode
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _stopTracking,
                      tooltip: 'Regresar al Monitor',
                    )
                  : _usuarioFiltroId != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            _aplicarFiltroUsuario(null, null);
                          },
                          tooltip: 'Volver a mis dispositivos',
                        )
                      : null,
              title: Text(
                _isTrackingMode && _trackedDevice != null
                    ? 'Siguiendo: ${_trackedDevice!.nombre}'
                    : _usuarioFiltroId != null 
                        ? (_usuarioFiltroNombre ?? 'Usuario')
                        : 'HusatGps',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
      body: Stack(
        // OPTIMIZACIÓN: clipBehavior ayuda en dispositivos Xiaomi a evitar errores de buffer al renderizar capas
        // Especialmente útil cuando hay múltiples widgets superpuestos (mapa, botones, paneles)
        clipBehavior: Clip.none,
        children: [
          // A. MAPA
          // OPTIMIZACIÓN: Usar RepaintBoundary para evitar rebuilds innecesarios del mapa
          RepaintBoundary(
            child: ValueListenableBuilder<Set<Marker>>(
              valueListenable: _markersNotifier,
              builder: (context, markers, child) {
                return GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-12.0464, -77.0428), // Lima Default
                    zoom: 12,
                  ),
                  markers: markers,
                  polylines: _polylines,

                // --- CONFIGURACIÓN DE "MI UBICACIÓN" (Punto Azul) ---
                myLocationEnabled: !_isShowingHistorial && !_isTrackingMode, // Desactivado en modo historial y seguimiento
                myLocationButtonEnabled: false, // Desactivado - usamos botón personalizado
                padding: EdgeInsets.only(
                  top: 60, // Padding estándar (sin banner)
                  bottom: 140, // Para que el logo de Google suba arriba de los paneles
                ),
                // ----------------------------------------------------
                trafficEnabled: _trafficEnabled, // Capa de tráfico

                onMapCreated: (controller) async {
                  _mapController = controller;
                  _customInfoWindowController.googleMapController = controller;
                  
                  // OPTIMIZACIÓN: Esperar un frame antes de mostrar dispositivos para mejor fluidez
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isShowingHistorial && _devices.isNotEmpty && !_isTrackingMode) {
                      _showAllDevicesOnMap();
                    }
                  });
                },
                onTap: (latLng) {
                  if (!_isShowingHistorial && !_isTrackingMode) {
                    _customInfoWindowController.hideInfoWindow?.call();
                    _deselectDevice();
                  }
                },
                onCameraMove: (position) {
                  _customInfoWindowController.onCameraMove?.call();
                },
                );
              },
            ),
          ),

          // B. INFO WINDOW (Burbuja de información) - Desactivado en modo historial
          if (!_isShowingHistorial)
            CustomInfoWindow(
              controller: _customInfoWindowController,
              height: _isTrackingMode ? 140 : 180,
              width: _isTrackingMode ? 200 : 230,
              offset: 35,
            ),

          // D. CONTADOR 10S (Solo en Monitor, no en seguimiento) - Izquierda Superior
          // OPTIMIZACIÓN: Usar ValueListenableBuilder para evitar rebuilds innecesarios
          if (!_isShowingHistorial && !_isTrackingMode)
            Positioned(
              top: 14,
              left: 14,
              child: ValueListenableBuilder<int>(
                valueListenable: _countdownNotifier,
                builder: (context, seconds, child) {
                  return FloatingActionButton.small(
                    heroTag: 'refreshBtn', // Tag único
                    backgroundColor: Colors.white,
                    elevation: 4, // Agregado elevación consistente
                    onPressed: _handleManualRefreshButton,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: seconds / 10,
                          color: AppConfig.primaryColor,
                          strokeWidth: 3,
                        ),
                        Text(
                          '$seconds',
                          style: TextStyle(
                            color: AppConfig.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // H. MENSAJE FLOTANTE DE ACTUALIZACIÓN (Centro entre contador y botón mi ubicación)
          if (_showSuccessMessage)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _showSuccessMessage ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -20 * (1 - value)), // Animación de deslizamiento
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Aumentado padding
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85), // Aumentado de 0.8 a 0.85
                      borderRadius: BorderRadius.circular(12), // Aumentado de 8 a 12
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Dispositivos actualizados',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13, // Aumentado de 12 a 13
                            fontWeight: FontWeight.w600, // Aumentado de w500 a w600
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // D.1. BOTÓN DE REGRESO PARA HISTORIAL (Cuando AppBar está oculto)
          if (_isShowingHistorial)
            Positioned(
              top: 14,
              left: 14,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'backHistorialBtn',
                  backgroundColor: Colors.white,
                  onPressed: _closeHistory,
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),

          // E. BOTÓN MI UBICACIÓN (Derecha Superior - misma altura que contador)
          if (!_isShowingHistorial && !_isTrackingMode)
            Positioned(
              top: 14, // Posición estándar (sin banner)
              right: 14,
              child: FloatingActionButton.small(
                heroTag: 'myLocationBtn',
                backgroundColor: Colors.white,
                elevation: 4, // Agregado elevación consistente
                onPressed: _goToMyLocation,
                child: Icon(
                  Icons.my_location,
                  color: Colors.grey[700],
                ),
              ),
            ),

          // G. BOTÓN DE TRÁFICO (Debajo del botón de mi ubicación)
          if (!_isShowingHistorial && !_isTrackingMode)
            Positioned(
              top: 70, // Posición estándar (sin banner) - Espaciado consistente de 56px
              right: 14,
              child: FloatingActionButton.small(
                heroTag: 'trafficBtn',
                backgroundColor: _trafficEnabled ? Colors.red : Colors.white,
                elevation: 4, // Agregado elevación consistente
                onPressed: () {
                  setState(() {
                    _trafficEnabled = !_trafficEnabled;
                  });
                },
                child: Icon(
                  Icons.traffic,
                  color: _trafficEnabled ? Colors.white : Colors.grey,
                ),
              ),
            ),

          // H. BOTÓN DE FILTRO DE SUPERVISIÓN (Debajo del botón de 10s - Solo Admins)
          // Alineado con los demás botones pequeños de la izquierda
          if (isAdmin && !_isShowingHistorial && !_isTrackingMode)
            Positioned(
              top: 70, // Debajo del botón de 10s (que está en top: 14, con ~56px de separación)
              left: 14, // Misma posición horizontal que el botón de 10s
              child: FloatingActionButton.small(
                heroTag: 'supervisionFilterBtn',
                backgroundColor: const Color(0xFFEF1A2D),
                elevation: 4, // Agregado elevación consistente
                onPressed: _showUsuarioSelectionModal,
                child: const Icon(Icons.people_alt, color: Colors.white, size: 20),
                tooltip: 'Filtro de Supervisión',
              ),
            ),

          // I. BOTÓN DE SOPORTE WHATSAPP (Parte inferior derecha con cartel)
          // Mantiene la misma separación de 15px desde el bottom navigation siempre
          if (!_isShowingHistorial && !_isTrackingMode)
            Positioned(
              bottom: _showActionBar ? 100: 10, // 120px altura panel + 15px separación cuando hay panel, 15px cuando no hay
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Cartel/Banner con mensaje
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366), // Verde WhatsApp
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '¿Necesitas ayuda?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Avatar sin fondo ni bordes - solo la imagen PNG con su forma original
                  GestureDetector(
                    onTap: _abrirWhatsAppSoporte,
                    child: Image.asset(
                      'assets/images/soporte_avatar.png',
                      width: 140, // Doble del tamaño anterior (70 * 2)
                      height: 140,
                      fit: BoxFit.contain, // Mantener proporción y forma original de la imagen
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback si la imagen no existe
                        return Container(
                          width: 140,
                          height: 140,
                          color: const Color(0xFF25D366),
                          child: const Icon(
                            Icons.support_agent,
                            color: Colors.white,
                            size: 70,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // E. PANEL INFERIOR UNIFICADO (Address + Actions) - Al seleccionar un vehículo
          if (_showActionBar && _selectedDevice != null && !_isShowingHistorial && !_isTrackingMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra de dirección simple
                    AddressBar(
                      latitude: _selectedDevice!.latitude,
                      longitude: _selectedDevice!.longitude,
                    ),
                    // Botones de acción (sin espacio entre ellos)
                    GlassActionBar(
                    onDetalle: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailsScreen(
                            device: _selectedDevice!,
                            latitude: _selectedDevice!.latitude,
                            longitude: _selectedDevice!.longitude,
                            speedKmh: _selectedDevice!.velocidad ?? 0.0,
                            status: (_selectedDevice!.movimiento ?? false) ? 'En Movimiento' : 'Estático',
                          ),
                        ),
                      );
                    },
                    onSeguimiento: () {
                      if (_selectedDevice != null) {
                        _startTracking(_selectedDevice!);
                      }
                    },
                    onHistorial: _toggleHistorialMode,
                    onComando: () {
                      showDialog(
                        context: context,
                        builder: (_) => VehicleCommandDialog(device: _selectedDevice!),
                      );
                    },
                    onCompartir: () {
                      ShareService().shareLocation(
                        placa: _selectedDevice!.placa ?? "Vehículo",
                        latitude: _selectedDevice!.latitude,
                        longitude: _selectedDevice!.longitude,
                      );
                    },
                    onVerMas: () {
                      // Determinar status basado en idEstadoOperativo
                      String status;
                      if (_selectedDevice!.idEstadoOperativo == 7) {
                        status = 'En Movimiento';
                      } else if (_selectedDevice!.idEstadoOperativo == 6) {
                        status = 'Estático';
                      } else if (_selectedDevice!.idEstadoOperativo == 4) {
                        status = 'Fuera de Línea';
                      } else {
                        status = (_selectedDevice!.movimiento ?? false) ? 'En Movimiento' : 'Estático';
                      }
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerMasScreen(
                            device: _selectedDevice!,
                            latitude: _selectedDevice!.latitude,
                            longitude: _selectedDevice!.longitude,
                            onSeguimiento: () {
                              if (_selectedDevice != null) {
                                _startTracking(_selectedDevice!);
                              }
                            },
                            onHistorial: _toggleHistorialMode,
                            onComando: () {
                              showDialog(
                                context: context,
                                builder: (_) => VehicleCommandDialog(device: _selectedDevice!),
                              );
                            },
                            onIconChanged: () {
                              // Actualizar marcadores del mapa con el nuevo icono
                              debugPrint('✅ Icono cambiado - Actualizando marcadores del mapa');
                              _refreshMarkers();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  ],
                ),
              ),
            ),

          // F. CONTROLES DE HISTORIAL (Solo en modo historial)
          if (_isShowingHistorial)
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: HistorialControlsOverlay(
                playbackSliderValue: _historyManager.getSliderValue(),
                playbackSpeed: _playbackSpeed,
                isPlaying: _historyManager.isPlayingHistorial,
                playbackHistoryLength: _historyManager.playbackHistory.length,
                onPlayPausePressed: () {
                  if (_selectedDevice == null) return;
                  _historyManager.togglePlayPause(
                    device: _selectedDevice!,
                    playbackSpeed: _playbackSpeed,
                    onLocationUpdate: _handleHistoryLocationUpdate,
                    onComplete: _handleHistoryComplete,
                  );
                  setState(() {});
                },
                onSpeedChanged: (speed) {
                  setState(() {
                    _playbackSpeed = speed;
                    _historyManager.setPlaybackSpeed(speed);
                    // Si está reproduciendo, reiniciar con la nueva velocidad
                    if (_historyManager.isPlayingHistorial && _selectedDevice != null) {
                      _historyManager.stopPlayback();
                      _historyManager.startPlayback(
                        device: _selectedDevice!,
                        playbackSpeed: speed,
                        onLocationUpdate: _handleHistoryLocationUpdate,
                        onComplete: _handleHistoryComplete,
                        startIndex: _historyManager.currentPlaybackIndex,
                      );
                    }
                  });
                },
                onSliderChanged: (val) {
                  if (_selectedDevice == null) return;
                  
                  // CRÍTICO: Validar que el valor no sea NaN antes de usar
                  if (val.isNaN || val.isInfinite) {
                    debugPrint('⚠️ ADVERTENCIA: onSliderChanged recibió valor inválido: $val');
                    return;
                  }
                  
                  // Asegurar que el valor esté en el rango válido [0.0, 1.0]
                  final valSanitizado = val.clamp(0.0, 1.0);
                  
                  _historyManager.seekTo(
                    valSanitizado,
                    device: _selectedDevice!,
                    playbackSpeed: _playbackSpeed,
                    onLocationUpdate: _handleHistoryLocationUpdate,
                    onComplete: _handleHistoryComplete,
                  );
                  setState(() {});
                },
                onSliderStart: () {
                  // Pausar mientras se arrastra el slider
                  if (_historyManager.isPlayingHistorial) {
                    _historyManager.stopPlayback();
                    setState(() {});
                  }
                },
              ),
            ),

          // G. LOADING (Carga general)
          if (_isLoadingDevices)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}