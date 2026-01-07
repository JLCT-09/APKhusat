import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'dart:math' as math;
import '../../domain/models/user.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/tracking_service.dart';
import 'login_screen.dart';
import 'devices_screen.dart' show DevicesScreen;
import '../../domain/models/device_model.dart' show DeviceModel, DeviceStatus;
import '../../domain/models/location_point.dart';
import '../../data/gps_service.dart';
import '../widgets/traffic_fab.dart';
import '../widgets/center_location_fab.dart';
import '../widgets/clear_map_fab.dart';
import '../widgets/vehicle_info_window.dart';
import '../widgets/glass_action_bar.dart';
import '../widgets/address_bar.dart';
import '../widgets/historial_bottom_sheet.dart';
import 'device_details_screen.dart';
import 'ver_mas_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:custom_info_window/custom_info_window.dart';
import '../../data/roads_service.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/device_monitoring_service.dart';
import '../../data/device_service.dart';
import '../../core/utils/storage_service.dart';
import '../../core/config/app_config.dart';
import 'alerts_history_screen.dart';
import 'profile_screen.dart';

class MapScreen extends StatefulWidget {
  final UserRole userRole;
  final DeviceModel? selectedDevice;
  final bool centerOnDevice;
  final int? notificationDeviceId;

  const MapScreen({
    super.key,
    required this.userRole,
    this.selectedDevice,
    this.centerOnDevice = false,
    this.notificationDeviceId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controladores
  GoogleMapController? _mapController;
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  final Location _location = Location();
  
  // Estado del mapa
  LatLng? _currentPosition;
  int _currentIndex = 0;
  bool _trafficEnabled = false;
  bool _isFullScreen = false;
  
  // Servicios
  final TrackingService _trackingService = TrackingService();
  StreamSubscription<LocationData>? _locationSubscription;
  
  // Polylines y marcadores
  final List<LatLng> _polylinePoints = [];
  final List<LatLng> _historialPoints = [];
  final List<List<LatLng>> _historialSegments = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  DateTime? _lastUpdateTime;
  LatLng? _myLocation;
  LatLng? _lastTrackedPosition;
  
  // Caché para puntos ajustados a carreteras
  List<LatLng>? _cachedSnappedPoints;
  bool _isProcessingSnap = false;
  
  // Variables para lógica de fallback al historial
  bool _isUsingFallbackLocation = false;
  List<GpsLocation> _recentHistory = [];
  double _calculatedDistance = 0.0;
  
  // Monitoreo en tiempo real
  DeviceModel? _monitoredDevice;
  Timer? _monitoringTimer;
  bool _isMonitoringRealTime = false;
  double _currentSpeed = 0.0;
  bool _isShowingHistorial = false;
  
  // Selección de vehículo
  DeviceModel? _selectedDevice;
  LatLng? _selectedDevicePosition;
  double _selectedDeviceSpeed = 0.0;
  String _selectedDeviceStatus = 'Detenido';
  bool _showInfoWindow = false;
  bool _showActionBar = false;
  
  // Variables para reproducción de historial
  bool _isPlayingHistorial = false;
  double _playbackSpeed = 1.0;
  int _currentPlaybackIndex = 0;
  Timer? _playbackTimer;
  List<GpsLocation> _playbackHistory = [];
  DeviceModel? _playbackDevice;
  
  // Lista de dispositivos
  List<DeviceModel> _devices = [];
  bool _isLoadingDevices = false;
  int? _pendingDeviceIdToFocus;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions().then((tienePermisos) {
      if (tienePermisos) {
        _initializeLocation();
        _initializeTracking();
        DeviceMonitoringService().startMonitoring();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadAllDevicesAndCreateMarkers();
        });
        
        if (widget.notificationDeviceId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            seleccionarVehiculoDesdeNotificacion(widget.notificationDeviceId!);
          });
        } else if (widget.selectedDevice != null && widget.centerOnDevice) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerOnSelectedDevice();
          });
        }
      } else {
        if (mounted) {
          _showErrorDialog('Se requieren permisos de ubicación para usar el mapa.');
        }
      }
    });
  }

  Future<bool> _checkLocationPermissions() async {
    bool servicioHabilitado = await _location.serviceEnabled();
    if (!servicioHabilitado) {
      servicioHabilitado = await _location.requestService();
      if (!servicioHabilitado) return false;
    }

    PermissionStatus estadoPermiso = await _location.hasPermission();
    if (estadoPermiso == PermissionStatus.denied || estadoPermiso == PermissionStatus.deniedForever) {
      estadoPermiso = await _location.requestPermission();
      if (estadoPermiso != PermissionStatus.granted && estadoPermiso != PermissionStatus.grantedLimited) {
        return false;
      }
    }

    return estadoPermiso == PermissionStatus.granted || estadoPermiso == PermissionStatus.grantedLimited;
  }

  Future<void> _fetchDevices() async {
    if (_isLoadingDevices) return;
    
    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final userId = await StorageService.getUserId() ?? '6';
      final devices = await DeviceService.getDispositivosPorUsuario(userId);
      
      final deviceMap = <int, DeviceModel>{};
      for (final device in devices) {
        if (device.idDispositivo > 0) {
          deviceMap[device.idDispositivo] = device;
        }
      }
      
      final uniqueDevices = deviceMap.values.toList();
      
      if (mounted) {
        setState(() {
          _devices = uniqueDevices;
          _isLoadingDevices = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar dispositivos: $e');
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> _loadAllDevicesAndCreateMarkers() async {
    if (_devices.isEmpty) {
      await _fetchDevices();
    }

    if (_mapController == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_mapController == null || !mounted) return;
    }

    final carIcon = await _createVehicleIcon();
    final newMarkers = <Marker>[];
    
    for (final device in _devices) {
      try {
        final ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
        
        LatLng? devicePosition;
        if (ultimaUbicacion != null && 
            _isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
          devicePosition = ultimaUbicacion.toLatLng();
        } else {
          if (_isValidCoordinate(device.latitude, device.longitude)) {
            devicePosition = LatLng(device.latitude, device.longitude);
          }
        }

        if (devicePosition != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('device_${device.idDispositivo}'),
              position: devicePosition,
              icon: carIcon,
              onTap: () {
                final currentDevice = _devices.firstWhere(
                  (d) => d.idDispositivo == device.idDispositivo,
                  orElse: () => device,
                );
                
                final speed = ultimaUbicacion?.speed ?? currentDevice.speed ?? 0.0;
                final speedKmh = speed * 3.6;
                final status = currentDevice.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                _selectVehicle(currentDevice, devicePosition!, speedKmh, status, isFallback: false);
              },
            ),
          );
        }
      } catch (e) {
        debugPrint('Error al crear marcador para dispositivo ${device.idDispositivo}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('device_'));
        _markers.addAll(newMarkers);
      });
    }
  }

  Future<void> seleccionarVehiculoDesdeNotificacion(int deviceId) async {
    if (_mapController == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_mapController == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronizando ubicación del vehículo...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    if (_devices.isEmpty || _isLoadingDevices) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronizando ubicación del vehículo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await _fetchDevices();
    }

    DeviceModel? device;
    try {
      device = _devices.firstWhere((d) => d.idDispositivo == deviceId);
    } catch (e) {
      await _fetchDevices();
      try {
        device = _devices.firstWhere((d) => d.idDispositivo == deviceId);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronizando ubicación del vehículo...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    GpsLocation? ultimaUbicacion;
    LatLng? devicePosition;
    
    try {
      ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
      
      if (ultimaUbicacion != null && 
          _isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
        devicePosition = ultimaUbicacion.toLatLng();
      } else {
        final fallbackLocation = await _getLastValidLocationFromHistory(device.idDispositivo.toString());
        if (fallbackLocation != null) {
          devicePosition = fallbackLocation.toLatLng();
        }
      }
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
    }

    if (devicePosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronizando ubicación del vehículo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(devicePosition, 15.0),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (device != null && devicePosition != null) {
      final deviceFinal = device;
      final positionFinal = devicePosition;
      
      await _createVehicleIcon().then((carIcon) {
        if (mounted) {
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'device_${deviceFinal.idDispositivo}');
            
            final currentDevice = _devices.firstWhere(
              (d) => d.idDispositivo == deviceFinal.idDispositivo,
              orElse: () => deviceFinal,
            );
            
            _markers.add(
              Marker(
                markerId: MarkerId('device_${currentDevice.idDispositivo}'),
                position: positionFinal,
                icon: carIcon,
                onTap: () {
                  final speed = ultimaUbicacion?.speed ?? currentDevice.speed ?? 0.0;
                  final speedKmh = speed * 3.6;
                  final status = currentDevice.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                  _selectVehicle(currentDevice, positionFinal, speedKmh, status, isFallback: false);
                },
              ),
            );
          });
        }
      });

      if (mounted) {
        final speed = ultimaUbicacion?.speed ?? deviceFinal.speed ?? 0.0;
        final speedKmh = speed * 3.6;
        final status = deviceFinal.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
        _selectVehicle(deviceFinal, positionFinal, speedKmh, status, isFallback: false);
      }
    }
  }

  Future<void> _focusDeviceById(int deviceId) async {
    if (_mapController == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_mapController == null || !mounted) return;
    }

    if (_devices.isEmpty) {
      await _fetchDevices();
    }

    DeviceModel? device;
    try {
      device = _devices.firstWhere((d) => d.idDispositivo == deviceId);
    } catch (e) {
      await _fetchDevices();
      try {
        device = _devices.firstWhere((d) => d.idDispositivo == deviceId);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró el vehículo seleccionado'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    final ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
    
    LatLng? devicePosition;
    if (ultimaUbicacion != null && 
        _isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
      devicePosition = ultimaUbicacion.toLatLng();
    } else {
      if (_isValidCoordinate(device.latitude, device.longitude)) {
        devicePosition = LatLng(device.latitude, device.longitude);
      }
    }

    if (devicePosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación del vehículo'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    DeviceModel currentDevice = device;
    final currentDeviceId = device.idDispositivo;
    if (currentDeviceId != null) {
      try {
        currentDevice = _devices.firstWhere(
          (d) => d.idDispositivo == currentDeviceId,
        );
      } catch (e) {
        // Usar el dispositivo pasado si no se encuentra
      }
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(devicePosition, 15.0),
    );

    await Future.delayed(const Duration(milliseconds: 300));

    await _createVehicleIcon().then((carIcon) {
      if (mounted) {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'device_${currentDevice.idDispositivo}');
          
          _markers.add(
            Marker(
              markerId: MarkerId('device_${currentDevice.idDispositivo}'),
              position: devicePosition!,
              icon: carIcon,
              onTap: () {
                final speed = ultimaUbicacion?.speed ?? currentDevice.speed ?? 0.0;
                final speedKmh = speed * 3.6;
                final status = currentDevice.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                _selectVehicle(currentDevice, devicePosition!, speedKmh, status, isFallback: false);
              },
            ),
          );
        });
      }
    });

    if (mounted) {
      final speed = ultimaUbicacion?.speed ?? currentDevice.speed ?? 0.0;
      final speedKmh = speed * 3.6;
      final status = currentDevice.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
      _selectVehicle(currentDevice, devicePosition!, speedKmh, status, isFallback: false);
    }
    
    _pendingDeviceIdToFocus = null;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _customInfoWindowController.googleMapController = controller;
    
    if (AppConfig.targetVehicleId != null) {
      final targetId = AppConfig.targetVehicleId;
      AppConfig.targetVehicleId = null;
      
      if (targetId != null) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted || _mapController == null) return;
          await seleccionarVehiculoDesdeNotificacion(targetId);
        });
      }
    } else if (_pendingDeviceIdToFocus != null) {
      final deviceId = _pendingDeviceIdToFocus;
      _pendingDeviceIdToFocus = null;
      
      final deviceIdToFocus = deviceId;
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted || _mapController == null || deviceIdToFocus == null) return;
        await _focusDeviceById(deviceIdToFocus);
      });
    }
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentPosition != null && _mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 16.0),
        );
      } else if (_myLocation != null && _mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_myLocation!, 16.0),
        );
      }
    });
  }

  void _selectVehicle(DeviceModel device, LatLng position, double speed, String status, {bool isFallback = false, DateTime? historialTimestamp, double? historialSpeed}) {
    DeviceModel deviceToUse = device;
    try {
      final updatedDevice = _devices.firstWhere(
        (d) => d.idDispositivo == device.idDispositivo,
      );
      deviceToUse = updatedDevice;
    } catch (e) {
      debugPrint('Dispositivo ${device.idDispositivo} no encontrado en lista, usando el pasado');
    }
    
    setState(() {
      _selectedDevice = deviceToUse;
      _selectedDevicePosition = position;
      _selectedDeviceSpeed = historialSpeed ?? speed;
      _selectedDeviceStatus = status;
      _showInfoWindow = true;
      _showActionBar = true;
      _isUsingFallbackLocation = isFallback;
    });
    
    _customInfoWindowController.addInfoWindow?.call(
      VehicleInfoWindow(
        device: deviceToUse,
        lastUpdate: historialTimestamp ?? deviceToUse.lastUpdate,
      ),
      position,
    );
    
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, 16.0),
      );
    }
  }

  void _openHistorialPicker(DeviceModel device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HistorialBottomSheet(
        device: device,
        onConfirm: (fechaDesde, fechaHasta, velocidadReproduccion) {
          _playbackSpeed = velocidadReproduccion;
          _playbackDevice = device;
          _loadHistorial(device, fechaDesde, fechaHasta);
        },
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0 && _currentIndex == 0) {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
      return;
    }
    
    setState(() {
      _currentIndex = index;
      _isFullScreen = false;
    });
    
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DevicesScreen(),
        ),
      ).then((result) async {
        if (result != null && result is DeviceModel) {
          final selectedDevice = result as DeviceModel;
          
          setState(() {
            _currentIndex = 0;
            _pendingDeviceIdToFocus = selectedDevice.idDispositivo;
          });
          
          await _focusDeviceById(selectedDevice.idDispositivo);
        }
      });
    }
  }

  void _clearSelection() {
    _customInfoWindowController.hideInfoWindow?.call();
    setState(() {
      _selectedDevice = null;
      _selectedDevicePosition = null;
      _showInfoWindow = false;
      _showActionBar = false;
    });
  }

  void _centerCameraOnMyLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16.0),
      );
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final ubicacionInicial = await _location.getLocation();
      if (ubicacionInicial.latitude != null && ubicacionInicial.longitude != null) {
        final posicionInicial = LatLng(
          ubicacionInicial.latitude!,
          ubicacionInicial.longitude!,
        );
        setState(() {
          _currentPosition = posicionInicial;
          _myLocation = posicionInicial;
          _lastTrackedPosition = posicionInicial;
          _lastUpdateTime = DateTime.now();
        });
        
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(posicionInicial, 16.0),
          );
        }
      }
    } catch (e) {
      // Error silencioso
    }

    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 3000,
      distanceFilter: 3.0,
    );
    
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData datosUbicacion) {
        if (datosUbicacion.latitude != null && datosUbicacion.longitude != null) {
          final nuevaPosicion = LatLng(
            datosUbicacion.latitude!,
            datosUbicacion.longitude!,
          );
          
          setState(() {
            _currentPosition = nuevaPosicion;
            _myLocation = nuevaPosicion;
            _lastUpdateTime = DateTime.now();
          });
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _initializeTracking() async {
    await _trackingService.initializeNotifications();

    _trackingService.onLocationUpdate = (LocationPoint location) {
      if (mounted) {
        final newLocation = LatLng(location.latitude, location.longitude);
        _currentPosition = newLocation;
        _lastUpdateTime = DateTime.now();
        _currentSpeed = location.speed ?? 0.0;
        
        _polylinePoints.add(newLocation);
        
        setState(() {
          // Actualizar polyline
        });
      }
    };

    _trackingService.onStopDetected = () {
      if (mounted) {
        _showStopDialog();
      }
    };

    if (widget.userRole == UserRole.client) {
      final started = await _trackingService.startTracking();
      if (!started && mounted) {
        _showErrorDialog('No se pudo iniciar el rastreo GPS');
      }
    }
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  Future<GpsLocation?> _getLastValidLocationFromHistory(String dispositivoId) async {
    try {
      final fechaDesde = DateTime.now().subtract(const Duration(hours: 24));
      final historial = await GpsService.getHistorial(
        dispositivoId,
        fechaDesde: fechaDesde,
        fechaHasta: DateTime.now(),
      );
      
      for (var ubicacion in historial.reversed) {
        if (_isValidCoordinate(ubicacion.latitude, ubicacion.longitude)) {
          return ubicacion;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error obteniendo historial para fallback: $e');
      return null;
    }
  }

  Future<void> _centerOnSelectedDevice() async {
    if (widget.selectedDevice != null && _mapController != null) {
      try {
        final ultimaUbicacion = await GpsService.getUltimaUbicacion(widget.selectedDevice!.idDispositivo.toString());
        
        GpsLocation? locationToUse = ultimaUbicacion;
        bool usingFallback = false;
        
        if (ultimaUbicacion == null || 
            !_isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
          final fallbackLocation = await _getLastValidLocationFromHistory(widget.selectedDevice!.idDispositivo.toString());
          if (fallbackLocation != null) {
            locationToUse = fallbackLocation;
            usingFallback = true;
          }
        }
        
        if (locationToUse != null) {
          final devicePosition = locationToUse.toLatLng();
          
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(devicePosition, 15.0),
          );
          
          _startRealTimeMonitoring(widget.selectedDevice!);
          
          _createVehicleIcon().then((carIcon) {
            setState(() {
              _markers.clear();
              _markers.add(
                Marker(
                  markerId: const MarkerId('selected_vehicle'),
                  position: devicePosition,
                  icon: carIcon,
                  onTap: () {
                    final status = widget.selectedDevice!.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                    final speed = locationToUse?.speed ?? widget.selectedDevice!.speed ?? 0.0;
                    _selectVehicle(widget.selectedDevice!, devicePosition, speed, status, isFallback: usingFallback);
                  },
                ),
              );
            });
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _startRealTimeMonitoring(DeviceModel device) {
    _stopRealTimeMonitoring();
    
    setState(() {
      _monitoredDevice = device;
      _isMonitoringRealTime = true;
      _isShowingHistorial = false;
      _historialPoints.clear();
      _historialSegments.clear();
      _polylinePoints.clear();
      _recentHistory.clear();
      _calculatedDistance = 0.0;
      _isUsingFallbackLocation = false;
    });
    
    _updateDeviceLocation(device);
    
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _isMonitoringRealTime && _monitoredDevice != null) {
        _updateDeviceLocation(_monitoredDevice!);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopRealTimeMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoringRealTime = false;
  }

  Future<void> _updateDeviceLocation(DeviceModel device) async {
    try {
      final ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
      
      GpsLocation? locationToUse = ultimaUbicacion;
      bool usingFallback = false;
      
      if (ultimaUbicacion == null || 
          !_isValidCoordinate(ultimaUbicacion.latitude, ultimaUbicacion.longitude)) {
        final fallbackLocation = await _getLastValidLocationFromHistory(device.idDispositivo.toString());
        if (fallbackLocation != null) {
          locationToUse = fallbackLocation;
          usingFallback = true;
        } else {
          return;
        }
      }
      
      if (locationToUse != null && mounted) {
        final newPosition = locationToUse.toLatLng();
        
        final speedMs = locationToUse.speed ?? 0.0;
        final speedKmh = speedMs * 3.6;
        await AlertService().checkSpeedAlert(device, speedKmh);
        await AlertService().checkCoverageAlert(device, locationToUse.timestamp);
        
        double distancia = 0.0;
        if (_lastTrackedPosition != null) {
          distancia = _calculateDistance(
            _lastTrackedPosition!.latitude,
            _lastTrackedPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );
        }
        
        if (_lastTrackedPosition == null || distancia > 3.0) {
          _createVehicleIcon().then((carIcon) {
            if (mounted) {
              setState(() {
                _markers.removeWhere((marker) => marker.markerId.value == 'selected_vehicle');
                _markers.add(
                  Marker(
                    markerId: const MarkerId('selected_vehicle'),
                    position: newPosition,
                    icon: carIcon,
                    onTap: () {
                      final status = device.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                      final speed = locationToUse?.speed ?? device.speed ?? 0.0;
                      _selectVehicle(device, newPosition, speed, status, isFallback: usingFallback);
                    },
                  ),
                );
                
                if (!usingFallback) {
                  _polylinePoints.add(newPosition);
                  _lastTrackedPosition = newPosition;
                }
              });
            }
          });
        }
      }
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _loadHistorial(DeviceModel device, DateTime fechaDesde, DateTime fechaHasta) async {
    _stopRealTimeMonitoring();
    _stopPlayback();
    
    setState(() {
      _isShowingHistorial = true;
      _isPlayingHistorial = false;
      _currentPlaybackIndex = 0;
      _historialPoints.clear();
      _historialSegments.clear();
      _polylinePoints.clear();
      _polylines.clear();
    });
    
    try {
      final historial = await GpsService.getHistorial(
        device.idDispositivo.toString(),
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );
      
      if (historial.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron recorridos en este horario'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      _playbackHistory = historial;
      
      if (historial.isNotEmpty && mounted) {
        final primeraUbicacion = historial.first;
        final ultimaUbicacionHistorial = historial.last;
        final primeraPosicion = primeraUbicacion.toLatLng();
        final ultimaPosicion = ultimaUbicacionHistorial.toLatLng();
        
        setState(() {
          final historialPoints = <LatLng>[];
          final historialTimestamps = <DateTime>[];
          
          LatLng? lastPoint;
          for (var ubicacion in historial) {
            final currentPoint = ubicacion.toLatLng();
            
            if (lastPoint == null || 
                (currentPoint.latitude != lastPoint.latitude || 
                 currentPoint.longitude != lastPoint.longitude)) {
              historialPoints.add(currentPoint);
              historialTimestamps.add(ubicacion.timestamp);
              lastPoint = currentPoint;
            }
          }
          
          if (historialPoints.length < 2) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No hay suficientes puntos de recorrido en este periodo'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          
          final segments = _filterLargeJumps(historialPoints, historialTimestamps);
          
          _historialSegments.clear();
          _historialPoints.clear();
          
          for (var segment in segments) {
            if (segment.length > 1) {
              final smoothedSegment = _interpolatePoints(segment);
              _historialSegments.add(smoothedSegment);
              _historialPoints.addAll(smoothedSegment);
            }
          }
          
          _updateHistorialPolyline();
        });
        
        Future.wait([
          _createStartIcon(),
          _createEndIcon(),
          _createVehicleIcon(),
        ]).then((icons) {
          if (mounted) {
            final startIcon = icons[0] as BitmapDescriptor;
            final endIcon = icons[1] as BitmapDescriptor;
            final vehicleIcon = icons[2] as BitmapDescriptor;
            
            setState(() {
              _markers.removeWhere((marker) => 
                marker.markerId.value == 'selected_vehicle' ||
                marker.markerId.value == 'historial_start' ||
                marker.markerId.value == 'historial_end'
              );
              
              _markers.add(
                Marker(
                  markerId: const MarkerId('historial_start'),
                  position: primeraPosicion,
                  icon: startIcon,
                  infoWindow: InfoWindow(
                    title: 'Inicio del Recorrido',
                    snippet: DateFormat('dd/MM/yyyy HH:mm').format(primeraUbicacion.timestamp),
                  ),
                ),
              );
              
              _markers.add(
                Marker(
                  markerId: const MarkerId('historial_end'),
                  position: ultimaPosicion,
                  icon: endIcon,
                  infoWindow: InfoWindow(
                    title: 'Fin del Recorrido',
                    snippet: DateFormat('dd/MM/yyyy HH:mm').format(ultimaUbicacionHistorial.timestamp),
                  ),
                ),
              );
              
              _markers.add(
                Marker(
                  markerId: const MarkerId('selected_vehicle'),
                  position: ultimaPosicion,
                  icon: vehicleIcon,
                  onTap: () {
                    final status = device.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido';
                    final speed = ultimaUbicacionHistorial.speed ?? device.speed;
                    _selectVehicle(
                      device, 
                      ultimaPosicion, 
                      speed, 
                      status, 
                      isFallback: false,
                      historialTimestamp: ultimaUbicacionHistorial.timestamp,
                      historialSpeed: ultimaUbicacionHistorial.speed,
                    );
                  },
                ),
              );
            });
            
            if (_historialPoints.isNotEmpty && _mapController != null) {
              _fitBoundsToHistorial();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar el historial'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startPlayback() {
    if (_playbackHistory.isEmpty || _playbackDevice == null) return;
    
    setState(() {
      _isPlayingHistorial = true;
      _currentPlaybackIndex = 0;
    });
    
    final baseInterval = Duration(milliseconds: (1000 / _playbackSpeed).round());
    
    _playbackTimer = Timer.periodic(baseInterval, (timer) {
      if (_currentPlaybackIndex >= _playbackHistory.length) {
        _stopPlayback();
        return;
      }
      
      final location = _playbackHistory[_currentPlaybackIndex];
      final position = location.toLatLng();
      
      _createVehicleIcon().then((carIcon) {
        if (mounted) {
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'playback_vehicle');
            
            _markers.add(
              Marker(
                markerId: const MarkerId('playback_vehicle'),
                position: position,
                icon: carIcon,
              ),
            );
            
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLng(position),
              );
            }
          });
        }
      });
      
      _currentPlaybackIndex++;
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    setState(() {
      _isPlayingHistorial = false;
    });
  }

  void _showMoreOptions(BuildContext context, DeviceModel device) {
    if (_selectedDevice == null || _selectedDevicePosition == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VerMasScreen(
          device: device,
          latitude: _selectedDevicePosition!.latitude,
          longitude: _selectedDevicePosition!.longitude,
          speedKmh: _selectedDeviceSpeed,
          status: _selectedDeviceStatus,
          onSeguimiento: () {
            if (_selectedDevice != null) {
              _startRealTimeMonitoring(_selectedDevice!);
            }
          },
          onHistorial: () {
            if (_selectedDevice != null) {
              _openHistorialPicker(_selectedDevice!);
            }
          },
          onComando: () {
            if (_selectedDevice != null) {
              _showCommandDialog(context, _selectedDevice!);
            }
          },
        ),
      ),
    );
  }

  void _showCommandDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Comandos del Vehículo',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleccione un comando para el vehículo:'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _sendMotorCommand(device, 'apagar');
              },
              icon: const Icon(Icons.power_off, color: Colors.white),
              label: const Text('Apagar Motor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _sendMotorCommand(device, 'restaurar');
              },
              icon: const Icon(Icons.power_settings_new, color: Colors.white),
              label: const Text('Restaurar Motor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMotorCommand(DeviceModel device, String command) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enviando comando de ${command == 'apagar' ? 'corte' : 'restauración'}...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comando ${command == 'apagar' ? 'de corte' : 'de restauración'} enviado'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _openNavigation(double latitude, double longitude) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir navegación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearMarkersAndRoute() {
    _customInfoWindowController.hideInfoWindow?.call();
    _stopRealTimeMonitoring();
    
    setState(() {
      _selectedDevice = null;
      _selectedDevicePosition = null;
      _selectedDeviceSpeed = 0.0;
      _selectedDeviceStatus = 'Detenido';
      _showInfoWindow = false;
      _showActionBar = false;
      
      _markers.clear();
      _polylinePoints.clear();
      _historialPoints.clear();
      _historialSegments.clear();
      _monitoredDevice = null;
      _cachedSnappedPoints = null;
      RoadsService.clearCache();
      _updatePolyline();
    });
  }

  void _updatePolyline() {
    _polylines.clear();
    
    if (_polylinePoints.length > 1) {
      final pointsToUse = _cachedSnappedPoints ?? _polylinePoints;
      final smoothedPoints = _interpolatePoints(pointsToUse);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_today'),
          points: smoothedPoints,
          color: Colors.red.withOpacity(0.7),
          width: 5,
          geodesic: true,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: 1,
        ),
      );
    }
    
    _updateHistorialPolyline();
  }

  void _updateHistorialPolyline() {
    _polylines.removeWhere((polyline) => 
      polyline.polylineId.value.startsWith('route_history')
    );
    
    if (_historialSegments.isNotEmpty) {
      for (int i = 0; i < _historialSegments.length; i++) {
        final segment = _historialSegments[i];
        if (segment.length > 1) {
          final smoothedPoints = _interpolatePoints(segment);
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_history_segment_$i'),
              points: smoothedPoints,
              color: Colors.red.withOpacity(0.7),
              width: 5,
              geodesic: true,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              zIndex: 2,
            ),
          );
        }
      }
    }
  }

  List<List<LatLng>> _filterLargeJumps(List<LatLng> points, List<DateTime>? timestamps) {
    if (points.length < 2) return [points];
    
    final segments = <List<LatLng>>[];
    final currentSegment = <LatLng>[points.first];
    const double maxDistanceMeters = 500.0;
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      
      final distance = _calculateDistance(
        prev.latitude, prev.longitude,
        current.latitude, current.longitude,
      );
      
      bool isLargeJump = distance > maxDistanceMeters;
      if (timestamps != null && i < timestamps.length) {
        final timeDiff = timestamps[i].difference(timestamps[i - 1]);
        if (distance > maxDistanceMeters && timeDiff.inSeconds < 2) {
          isLargeJump = true;
        }
      }
      
      if (isLargeJump) {
        if (currentSegment.length > 1) {
          segments.add(List.from(currentSegment));
        }
        currentSegment.clear();
        currentSegment.add(current);
      } else {
        currentSegment.add(current);
      }
    }
    
    if (currentSegment.length > 1) {
      segments.add(currentSegment);
    }
    
    return segments.isEmpty ? [points] : segments;
  }

  List<LatLng> _interpolatePoints(List<LatLng> points) {
    if (points.length < 2) return points;
    
    final interpolated = <LatLng>[points.first];
    const double maxDistanceMeters = 100.0;
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      
      final distance = _calculateDistance(
        prev.latitude, prev.longitude,
        current.latitude, current.longitude,
      );
      
      if (distance > maxDistanceMeters) {
        final numSteps = (distance / maxDistanceMeters).ceil();
        for (int step = 1; step < numSteps; step++) {
          final ratio = step / numSteps;
          final interpolatedLat = prev.latitude + (current.latitude - prev.latitude) * ratio;
          final interpolatedLng = prev.longitude + (current.longitude - prev.longitude) * ratio;
          interpolated.add(LatLng(interpolatedLat, interpolatedLng));
        }
      }
      
      interpolated.add(current);
    }
    
    return interpolated;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371000;
    final double diferenciaLat = _toRadians(lat2 - lat1);
    final double diferenciaLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(diferenciaLat / 2) * math.sin(diferenciaLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(diferenciaLon / 2) * math.sin(diferenciaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return radioTierra * c;
  }

  double _toRadians(double grados) {
    return grados * (math.pi / 180.0);
  }

  void _fitBoundsToHistorial() {
    if (_mapController == null || _historialPoints.isEmpty) return;
    
    double minLat = _historialPoints.first.latitude;
    double maxLat = _historialPoints.first.latitude;
    double minLng = _historialPoints.first.longitude;
    double maxLng = _historialPoints.first.longitude;
    
    for (var point in _historialPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  Future<BitmapDescriptor> _createStartIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(60, 60);
    
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      borderPaint,
    );
    
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.35, size.height * 0.25);
    path.lineTo(size.width * 0.35, size.height * 0.75);
    path.lineTo(size.width * 0.75, size.height * 0.5);
    path.close();
    canvas.drawPath(path, iconPaint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createEndIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(60, 60);
    
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      borderPaint,
    );
    
    final flagPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final flagPath = Path();
    flagPath.moveTo(size.width * 0.3, size.height * 0.3);
    flagPath.lineTo(size.width * 0.7, size.height * 0.5);
    flagPath.lineTo(size.width * 0.3, size.height * 0.7);
    flagPath.close();
    canvas.drawPath(flagPath, flagPaint);
    
    final polePaint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.3, size.height * 0.8),
      polePaint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createVehicleIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 80);
    
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.35, size.width * 0.7, size.height * 0.35),
      const Radius.circular(6),
    );
    canvas.drawRRect(carBody, iconPaint);
    
    final windowPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.4, size.width * 0.2, size.height * 0.15),
        const Radius.circular(2),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.4, size.width * 0.2, size.height * 0.15),
        const Radius.circular(2),
      ),
      windowPaint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Husat GPS',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(
              Icons.location_off,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Text(
              'Parada Detectada',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        content: const Text(
          'El vehículo no se ha movido más de 2 metros durante 30 segundos.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Set<Marker> _getMarkers() {
    return _markers;
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          onTap: (LatLng position) {
            _clearSelection();
            _customInfoWindowController.hideInfoWindow?.call();
          },
          onCameraMove: (CameraPosition position) {
            if (_showInfoWindow && _selectedDevicePosition != null) {
              _customInfoWindowController.onCameraMove?.call();
            }
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition ?? const LatLng(-8.1116, -79.0288),
            zoom: 16.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          padding: const EdgeInsets.only(top: 100),
          markers: _getMarkers(),
          polylines: _polylines,
          mapType: MapType.normal,
          trafficEnabled: _trafficEnabled,
        ),
        CustomInfoWindow(
          controller: _customInfoWindowController,
          height: 200,
          width: 280,
          offset: 50,
        ),
        if (_isFullScreen)
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isFullScreen = false;
                });
              },
              backgroundColor: Colors.red,
              elevation: 4,
              heroTag: 'exit_fullscreen',
              mini: true,
              child: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        if (!_isFullScreen)
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrafficFab(
                  trafficEnabled: _trafficEnabled,
                  onPressed: () {
                    setState(() {
                      _trafficEnabled = !_trafficEnabled;
                    });
                  },
                ),
                const SizedBox(height: 12),
                CenterLocationFab(
                  onPressed: _centerCameraOnMyLocation,
                ),
                const SizedBox(height: 12),
                if (_markers.isNotEmpty)
                  ClearMapFab(
                    onPressed: _clearMarkersAndRoute,
                  ),
                if (_isShowingHistorial && _playbackHistory.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (_isPlayingHistorial) {
                          _stopPlayback();
                        } else {
                          _startPlayback();
                        }
                      },
                      backgroundColor: Colors.red,
                      heroTag: 'playback_control',
                      mini: true,
                      child: Icon(
                        _isPlayingHistorial ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HusatGps'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Container(
          color: Colors.red,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
                SizedBox(height: 24),
                Text(
                  'Localizando vehículo...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget currentView;
    switch (_currentIndex) {
      case 0:
        currentView = _buildMapView();
        break;
      case 1:
        currentView = _buildMapView();
        break;
      case 2:
        currentView = AlertsHistoryScreen(userRole: widget.userRole);
        break;
      case 3:
        currentView = const ProfileScreen();
        break;
      default:
        currentView = _buildMapView();
    }

    if (_isFullScreen && _currentIndex == 0) {
      return Scaffold(
        body: currentView,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Husat GPS'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          currentView,
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
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
              if (_currentIndex == 0 && _showActionBar && _selectedDevice != null && _selectedDevicePosition != null)
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AddressBar(
                        latitude: _selectedDevicePosition!.latitude,
                        longitude: _selectedDevicePosition!.longitude,
                      ),
                      Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      GlassActionBar(
                        onDetalle: () {
                          if (_selectedDevice != null && _selectedDevicePosition != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DeviceDetailsScreen(
                                  device: _selectedDevice!,
                                  latitude: _selectedDevicePosition!.latitude,
                                  longitude: _selectedDevicePosition!.longitude,
                                  speedKmh: _selectedDeviceSpeed,
                                  status: _selectedDeviceStatus,
                                ),
                              ),
                            );
                          }
                        },
                        onSeguimiento: () {
                          if (_selectedDevice != null) {
                            _startRealTimeMonitoring(_selectedDevice!);
                          }
                        },
                        onHistorial: () {
                          if (_selectedDevice != null) {
                            _openHistorialPicker(_selectedDevice!);
                          }
                        },
                        onComando: () {
                          if (_selectedDevice != null) {
                            _showCommandDialog(context, _selectedDevice!);
                          }
                        },
                        onCompartir: () {
                          if (_selectedDevice != null && _selectedDevicePosition != null) {
                            ShareService().shareLocation(
                              placa: _selectedDevice!.placa ?? 'Sin Placa',
                              latitude: _selectedDevicePosition!.latitude,
                              longitude: _selectedDevicePosition!.longitude,
                            );
                          }
                        },
                        onVerMas: () {
                          if (_selectedDevice != null) {
                            _showMoreOptions(context, _selectedDevice!);
                          }
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
              BottomNavigationBar(
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                onTap: _onBottomNavTapped,
                selectedItemColor: Colors.red,
                unselectedItemColor: Colors.grey,
                backgroundColor: Colors.white,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.public),
                    label: 'Monitor',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.devices),
                    label: 'Dispositivos',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications_active),
                    label: 'Alerta',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Yo',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopPlayback();
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    DeviceMonitoringService().stopMonitoring();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackingService.stopTracking();
    _customInfoWindowController.dispose();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }
}
