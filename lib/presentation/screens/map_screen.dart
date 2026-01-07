import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import '../../domain/models/user.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/tracking_service.dart';
import 'login_screen.dart';
import 'devices_screen.dart' show DevicesScreen;
import '../../domain/models/device_model.dart' show DeviceModel, DeviceStatus;
import '../../data/gps_service.dart';
import '../widgets/traffic_fab.dart';
import '../widgets/center_location_fab.dart';
import '../widgets/clear_map_fab.dart';
import '../widgets/telemetry_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  final UserRole userRole;
  final DeviceModel? selectedDevice; // Vehículo seleccionado desde DevicesScreen
  final bool centerOnDevice; // Si debe centrar en el vehículo seleccionado

  const MapScreen({
    super.key,
    required this.userRole,
    this.selectedDevice,
    this.centerOnDevice = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentPosition;
  int _currentIndex = 0;
  bool _trafficEnabled = false;
  bool _isFullScreen = false;

  final TrackingService _trackingService = TrackingService();
  StreamSubscription<LocationData>? _locationSubscription;
  
  final List<LatLng> _polylinePoints = [];
  final List<LatLng> _historialPoints = [];
  final List<List<LatLng>> _historialSegments = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  DateTime? _lastUpdateTime;
  LatLng? _myLocation;
  LatLng? _lastTrackedPosition;
  
  DeviceModel? _monitoredDevice;
  Timer? _monitoringTimer;
  bool _isMonitoringRealTime = false;

  @override
  void initState() {
    super.initState();
    // Verificar permisos de ubicación de forma robusta antes de inicializar
    _checkLocationPermissions().then((tienePermisos) {
      if (tienePermisos) {
        _initializeLocation();
        _initializeTracking();
        
        // Si hay un vehículo seleccionado, centrar en él
        if (widget.selectedDevice != null && widget.centerOnDevice) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerOnSelectedDevice();
          });
        }
      } else {
        // Si no hay permisos, mostrar error y no cargar el mapa
        if (mounted) {
          _showErrorDialog('Se requieren permisos de ubicación para usar el mapa. El punto azul no aparecerá sin permisos.');
        }
      }
    });
  }
  
  /// Verifica y solicita permisos de ubicación de forma robusta.
  /// 
  /// Este método es crítico para que el punto azul nativo de Google Maps aparezca.
  /// Sin permisos explícitos, myLocationEnabled no funcionará correctamente.
  /// 
  /// Retorna true si los permisos fueron otorgados, false en caso contrario.
  Future<bool> _checkLocationPermissions() async {
    // Paso 1: Verificar si el servicio de ubicación está habilitado
    bool servicioHabilitado = await _location.serviceEnabled();
      if (!servicioHabilitado) {
        servicioHabilitado = await _location.requestService();
        if (!servicioHabilitado) {
          return false;
        }
      }

    PermissionStatus estadoPermiso = await _location.hasPermission();
    
    if (estadoPermiso == PermissionStatus.denied || estadoPermiso == PermissionStatus.deniedForever) {
      estadoPermiso = await _location.requestPermission();
      
      if (estadoPermiso != PermissionStatus.granted && estadoPermiso != PermissionStatus.grantedLimited) {
        return false;
      }
    }

    return estadoPermiso == PermissionStatus.granted || 
           estadoPermiso == PermissionStatus.grantedLimited;
  }
  
  
  /// Centra la cámara del mapa en el dispositivo seleccionado desde la lista de dispositivos.
  /// 
  /// Carga la última ubicación real desde el backend y crea un marcador de carro rojo.
  /// También carga el historial GPS para mostrar el rastro.
  Future<void> _centerOnSelectedDevice() async {
    if (widget.selectedDevice != null && _mapController != null) {
      try {
        // Cargar última ubicación real desde el backend usando idDispositivo
        final ultimaUbicacion = await GpsService.getUltimaUbicacion(widget.selectedDevice!.idDispositivo.toString());
        
        if (ultimaUbicacion != null) {
          final devicePosition = ultimaUbicacion.toLatLng();
          
          // Centrar cámara en la ubicación real
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(devicePosition, 15.0),
          );
          
          // Iniciar monitoreo en tiempo real del dispositivo seleccionado
          _startRealTimeMonitoring(widget.selectedDevice!);
          
          // Agregar marcador inicial del vehículo seleccionado con icono de carro rojo
          _createVehicleIcon().then((carIcon) {
            setState(() {
              _markers.clear(); // Limpiar marcadores anteriores
              _markers.add(
                Marker(
                  markerId: const MarkerId('selected_vehicle'),
                  position: devicePosition,
                  icon: carIcon, // Usar icono de carro rojo
                  onTap: () {
                    // Mostrar BottomSheet con información del vehículo (incluye IMEI)
                    _showVehicleInfoBottomSheet(
                      devicePosition,
                      ultimaUbicacion.speed ?? widget.selectedDevice!.speed,
                      widget.selectedDevice!.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                      DateFormat('HH:mm:ss').format(ultimaUbicacion.timestamp),
                      imei: widget.selectedDevice!.imei,
                      device: widget.selectedDevice,
                    );
                  },
                ),
              );
            });
          });
        } else {
          // Si no hay última ubicación, usar las coordenadas del dispositivo
          final devicePosition = LatLng(
            widget.selectedDevice!.latitude,
            widget.selectedDevice!.longitude,
          );
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(devicePosition, 15.0),
          );
        }
      } catch (e) {
        if (mounted) {
          String mensajeError = 'Error de comunicación con Husat';
          if (e.toString().contains('Código:')) {
            mensajeError = e.toString().replaceFirst('Exception: ', '');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeError),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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
      // Error silencioso: la ubicación se obtendrá del stream
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
          
          final esPrimeraUbicacion = _currentPosition == null;
          
          double distancia = 0.0;
          if (_lastTrackedPosition != null) {
            distancia = _calculateDistance(
              _lastTrackedPosition!.latitude,
              _lastTrackedPosition!.longitude,
              nuevaPosicion.latitude,
              nuevaPosicion.longitude,
            );
          }
          
          setState(() {
            _currentPosition = nuevaPosicion;
            _myLocation = nuevaPosicion;
            _lastUpdateTime = DateTime.now();
            
            if (widget.userRole == UserRole.client) {
              _updateVehicleMarker(nuevaPosicion, datosUbicacion.speed);
              
              if (_lastTrackedPosition == null || distancia > 3.0) {
                _polylinePoints.add(nuevaPosicion);
                _lastTrackedPosition = nuevaPosicion;
                _updatePolyline();
              }
            }
          });
          
          if (esPrimeraUbicacion && _mapController != null && widget.selectedDevice == null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(nuevaPosicion, 16.0),
            );
          }
        }
      },
      onError: (_) {
        // Error silencioso: el stream se reconectará automáticamente
      },
    );
  }

  /// Inicializa el servicio de rastreo GPS en segundo plano.
  /// 
  /// Configura callbacks para:
  /// - Actualizaciones de ubicación en tiempo real
  /// - Detección de paradas (30 segundos sin movimiento > 2m)
  /// 
  /// Solo inicia el rastreo si el usuario es cliente.
  Future<void> _initializeTracking() async {
    // Inicializar notificaciones
    await _trackingService.initializeNotifications();

    // Configurar callbacks
    _trackingService.onLocationUpdate = (LocationPoint location) {
      if (mounted) {
        // Actualizar posición actual
        final newLocation = LatLng(location.latitude, location.longitude);
        _currentPosition = newLocation;
        _lastUpdateTime = DateTime.now(); // Actualizar hora del último reporte
        _currentSpeed = location.speed; // Velocidad en m/s
        
        _polylinePoints.add(newLocation);
        
        setState(() {
          _updateVehicleMarker(newLocation, location.speed);
          _updatePolyline();
        });
      }
    };

    _trackingService.onStopDetected = () {
      if (mounted) {
        _showStopDialog();
      }
    };

    // Iniciar rastreo si es cliente
    if (widget.userRole == UserRole.client) {
      final started = await _trackingService.startTracking();
      if (!started && mounted) {
        _showErrorDialog('No se pudo iniciar el rastreo GPS');
      }
    }
  }

  /// Calcula la distancia entre dos puntos geográficos usando la fórmula de Haversine.
  /// 
  /// Esta fórmula es precisa para distancias cortas y medias en la superficie terrestre.
  /// Retorna la distancia en metros.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371000; // Radio de la Tierra en metros
    final double diferenciaLat = _toRadians(lat2 - lat1);
    final double diferenciaLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(diferenciaLat / 2) * math.sin(diferenciaLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(diferenciaLon / 2) * math.sin(diferenciaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return radioTierra * c;
  }

  /// Convierte grados a radianes.
  double _toRadians(double grados) {
    return grados * (math.pi / 180.0);
  }

  /// Actualiza la polyline (línea roja) que muestra el rastro del vehículo.
  /// 
  /// Solo se muestra para clientes y si hay más de un punto en el rastro.
  /// La línea es roja (identidad HusatGps) con 70% de opacidad y 7px de ancho.
  /// Actualiza las polylines (líneas) que muestran el rastro del vehículo.
  /// 
  /// - Ruta de hoy (roja): Se muestra cuando está en monitoreo en tiempo real
  /// - Ruta histórica (azul): Se muestra cuando se carga historial
  /// Ambas pueden mostrarse simultáneamente para comparación.
  /// Filtra y segmenta puntos para evitar saltos irrealistas.
  /// 
  /// Si la distancia entre dos puntos es mayor a 500 metros, se considera un error de señal
  /// y se crea un segmento separado (discontinuo) para no atravesar la ciudad de forma irreal.
  /// 
  /// Retorna una lista de segmentos, donde cada segmento es una lista de puntos continuos.
  List<List<LatLng>> _filterLargeJumps(List<LatLng> points, List<DateTime>? timestamps) {
    if (points.length < 2) return [points];
    
    final segments = <List<LatLng>>[];
    final currentSegment = <LatLng>[points.first];
    const double maxDistanceMeters = 500.0; // Distancia máxima para considerar continuidad
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      
      // Calcular distancia en metros
      final distance = _calculateDistance(
        prev.latitude, prev.longitude,
        current.latitude, current.longitude,
      );
      
      // Si hay timestamps, verificar también el tiempo transcurrido
      bool isLargeJump = distance > maxDistanceMeters;
      if (timestamps != null && i < timestamps.length) {
        final timeDiff = timestamps[i].difference(timestamps[i - 1]);
        // Si hay más de 500m en menos de 2 segundos, es un error de señal
        if (distance > maxDistanceMeters && timeDiff.inSeconds < 2) {
          isLargeJump = true;
        }
      }
      
      if (isLargeJump) {
        // Guardar el segmento actual y empezar uno nuevo
        if (currentSegment.length > 1) {
          segments.add(List.from(currentSegment));
        }
        currentSegment.clear();
        currentSegment.add(current);
      } else {
        currentSegment.add(current);
      }
    }
    
    // Agregar el último segmento
    if (currentSegment.length > 1) {
      segments.add(currentSegment);
    }
    
    return segments.isEmpty ? [points] : segments;
  }
  
  /// Interpola puntos intermedios para saltos grandes entre ubicaciones
  /// 
  /// Si la distancia entre dos puntos es mayor a 100 metros, añade puntos intermedios
  /// para que la línea siga mejor las calles en lugar de atravesar edificios.
  List<LatLng> _interpolatePoints(List<LatLng> points) {
    if (points.length < 2) return points;
    
    final interpolated = <LatLng>[points.first];
    const double maxDistanceMeters = 100.0; // Distancia máxima sin interpolar
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      
      // Calcular distancia en metros usando fórmula de Haversine
      final distance = _calculateDistance(
        prev.latitude, prev.longitude,
        current.latitude, current.longitude,
      );
      
      if (distance > maxDistanceMeters) {
        // Interpolar: añadir puntos intermedios
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
  
  void _updatePolyline() {
    _polylines.clear();
    
    if (_polylinePoints.length > 1) {
      final smoothedPoints = _interpolatePoints(_polylinePoints);
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
    
    if (_historialSegments.isNotEmpty) {
      for (int i = 0; i < _historialSegments.length; i++) {
        final segment = _historialSegments[i];
        if (segment.length > 1) {
          final smoothedPoints = _interpolatePoints(segment);
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_history_segment_$i'),
              points: smoothedPoints,
              color: Colors.blue.withOpacity(0.7),
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

  /// Crea un icono verde circular para el marcador de inicio del recorrido.
  Future<BitmapDescriptor> _createStartIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(60, 60);
    
    // Fondo circular verde
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Borde blanco
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      borderPaint,
    );
    
    // Icono de play/inicio
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
  
  /// Crea un icono de banderín (checkered flag) para el marcador de fin del recorrido.
  Future<BitmapDescriptor> _createEndIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(60, 60);
    
    // Fondo circular rojo
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Borde blanco
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      borderPaint,
    );
    
    // Dibujar banderín (triángulo)
    final flagPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final flagPath = Path();
    flagPath.moveTo(size.width * 0.3, size.height * 0.3);
    flagPath.lineTo(size.width * 0.7, size.height * 0.5);
    flagPath.lineTo(size.width * 0.3, size.height * 0.7);
    flagPath.close();
    canvas.drawPath(flagPath, flagPaint);
    
    // Poste del banderín
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
  
  /// Crea un icono personalizado de carro rojo para los marcadores de vehículos.
  /// 
  /// Los vehículos de terceros (flota) se muestran con este icono rojo,
  /// diferenciándose del punto azul nativo de Google Maps que muestra mi ubicación.
  Future<BitmapDescriptor> _createVehicleIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 80);
    
    // Fondo circular rojo
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Dibujar icono de carro (directions_car simplificado)
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Cuerpo del carro (rectángulo redondeado)
    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.35, size.width * 0.7, size.height * 0.35),
      const Radius.circular(6),
    );
    canvas.drawRRect(carBody, iconPaint);
    
    // Ventanas del carro
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

  /// Actualiza el marcador del vehículo en tiempo real con telemetría.
  /// 
  /// Crea un marcador con icono de carro rojo que muestra:
  /// - Posición actual del vehículo
  /// - Velocidad convertida de m/s a km/h
  /// - Estado (En Movimiento / Detenido)
  /// 
  /// Al presionar el marcador, se muestra un BottomSheet con información detallada.
  void _updateVehicleMarker(LatLng position, double? speedInMs) async {
    // Convertir velocidad de m/s a km/h
    final speedKmh = (speedInMs ?? 0.0) * 3.6;
    
    // Determinar estado según velocidad
    final isMoving = speedKmh >= 1.0;
    final statusText = isMoving ? 'En Movimiento' : 'Detenido';
    
    // Formatear hora con DateFormat
    final timeString = _lastUpdateTime != null
        ? DateFormat('HH:mm:ss').format(_lastUpdateTime!)
        : DateFormat('HH:mm:ss').format(DateTime.now());
    
    // Crear icono de carro rojo
    final carIcon = await _createVehicleIcon();
    
    // Limpiar marcadores de vehículos (pero mantener el vehículo seleccionado si existe)
    _markers.removeWhere((marker) => marker.markerId.value == 'vehicle_marker');
    
    // Solo agregar marcador de carro rojo si es cliente (mi ubicación se muestra con punto azul nativo de Google)
    if (widget.userRole == UserRole.client) {
      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle_marker'),
          position: position,
          icon: carIcon,
          onTap: () {
            // Mostrar BottomSheet con información vertical
            _showVehicleInfoBottomSheet(position, speedKmh, statusText, timeString, imei: null);
          },
        ),
      );
    }
    
    // Si hay un vehículo seleccionado desde la lista de Dispositivos, cargar ubicación real
    if (widget.selectedDevice != null) {
      // Cargar última ubicación real de forma asíncrona usando idDispositivo
      GpsService.getUltimaUbicacion(widget.selectedDevice!.idDispositivo.toString()).then((ultimaUbicacion) {
        if (ultimaUbicacion != null && mounted) {
          final devicePosition = ultimaUbicacion.toLatLng();
          setState(() {
            _markers.removeWhere((marker) => marker.markerId.value == 'selected_vehicle');
            _markers.add(
              Marker(
                markerId: const MarkerId('selected_vehicle'),
                position: devicePosition,
                icon: carIcon, // Usar el mismo icono de carro rojo
                onTap: () {
                  // Mostrar BottomSheet con información del vehículo seleccionado
                    _showVehicleInfoBottomSheet(
                      devicePosition,
                      ultimaUbicacion.speed ?? widget.selectedDevice!.speed,
                      widget.selectedDevice!.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                      DateFormat('HH:mm:ss').format(ultimaUbicacion.timestamp),
                      imei: widget.selectedDevice!.imei,
                      device: widget.selectedDevice,
                    );
                },
              ),
            );
          });
        } else if (mounted) {
          // Si no hay última ubicación, usar las coordenadas del dispositivo
          final devicePosition = LatLng(
            widget.selectedDevice!.latitude,
            widget.selectedDevice!.longitude,
          );
          setState(() {
            _markers.removeWhere((marker) => marker.markerId.value == 'selected_vehicle');
            _markers.add(
              Marker(
                markerId: const MarkerId('selected_vehicle'),
                position: devicePosition,
                icon: carIcon,
                onTap: () {
                  _showVehicleInfoBottomSheet(
                    devicePosition,
                    widget.selectedDevice!.speed,
                    widget.selectedDevice!.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                    DateFormat('HH:mm:ss').format(widget.selectedDevice!.lastUpdate),
                    imei: widget.selectedDevice!.imei,
                    device: widget.selectedDevice,
                  );
                },
              ),
            );
          });
        }
      }).catchError((_) {
        // Error silencioso
      });
    }
  }
  
  /// Muestra un BottomSheet con información detallada del vehículo.
  /// 
  /// Usa el widget modular TelemetryBottomSheet para mostrar:
  /// - Estado (En Movimiento / Detenido)
  /// - Velocidad en km/h
  /// - Latitud y Longitud con 6 decimales
  /// - Hora de última actualización
  /// - IMEI del dispositivo para confirmar identidad
  /// - Botón para ver historial de recorrido
  void _showVehicleInfoBottomSheet(
    LatLng position,
    double speedKmh,
    String status,
    String time, {
    String? imei,
    DeviceModel? device,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TelemetryBottomSheet(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
        status: status,
        time: time,
        imei: imei,
        device: device ?? _monitoredDevice,
        onLoadHistorial: device != null || _monitoredDevice != null
            ? (device, fechaDesde, fechaHasta) {
                _loadHistorial(device, fechaDesde, fechaHasta);
              }
            : null,
      ),
    );
  }

  /// Callback que se ejecuta cuando el mapa de Google Maps se crea.
  /// 
  /// Guarda la referencia del controlador y centra automáticamente
  /// la cámara en la ubicación actual del usuario con zoom 16.
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Centrar automáticamente en la ubicación real del usuario con zoom 16
    // Esperar un momento para asegurar que los permisos estén activos
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentPosition != null && _mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            _currentPosition!,
            16.0,
          ),
        );
      } else if (_myLocation != null && _mapController != null && mounted) {
        // Si _currentPosition es null pero _myLocation tiene valor, usar ese
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            _myLocation!,
            16.0,
          ),
        );
      }
    });
  }

  /// Centra la cámara del mapa en la ubicación actual del usuario.
  /// 
  /// Se ejecuta al presionar el botón de centrado (mira telescópica).
  /// Usa zoom 16 para mostrar la calle actual.
  void _centerCameraOnMyLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          _currentPosition!,
          16.0,
        ),
      );
    }
  }

  /// Obtiene el conjunto de marcadores actuales del mapa.
  /// 
  /// Incluye:
  /// - Marcador del vehículo propio (carro rojo) si es cliente
  /// - Marcador del vehículo seleccionado desde la lista de dispositivos
  /// 
  /// El punto azul nativo de Google Maps se maneja por separado con myLocationEnabled.
  Set<Marker> _getMarkers() {
    return _markers;
  }

  /// Muestra un diálogo de error con el mensaje proporcionado.
  /// 
  /// Usa el estilo de HusatGps (rojo) y permite al usuario cerrarlo.
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

  /// Muestra un diálogo cuando se detecta que el vehículo está detenido.
  /// 
  /// Se activa cuando el vehículo no se ha movido más de 2 metros durante 30 segundos.
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

  /// Maneja la navegación entre las diferentes pestañas del BottomNavigationBar.
  /// 
  /// Índices:
  /// - 0: Monitor (mapa principal)
  /// - 1: Dispositivos (lista de vehículos)
  /// - 2: Alerta (placeholder)
  /// - 3: Yo (perfil del usuario)
  /// 
  /// Si se presiona Monitor dos veces, alterna el modo pantalla completa.
  void _onBottomNavTapped(int index) {
    // Si presiona Monitor (index 0) cuando ya está en Monitor, alternar pantalla completa
    if (index == 0 && _currentIndex == 0) {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
      return;
    }
    
    setState(() {
      _currentIndex = index;
      _isFullScreen = false; // Salir de pantalla completa al cambiar de pestaña
    });
    
    // Navegación según el índice
    if (index == 1) { // Dispositivos
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DevicesScreen(),
        ),
      ).then((result) async {
        // Si se seleccionó un dispositivo, volver al Monitor y cargar ubicación real
        if (result != null && result is DeviceModel) {
          setState(() {
            _currentIndex = 0; // Volver a Monitor
          });
          
          try {
            // Cargar última ubicación real desde el backend usando idDispositivo
            final ultimaUbicacion = await GpsService.getUltimaUbicacion(result.idDispositivo.toString());
            
            if (ultimaUbicacion != null) {
              final devicePosition = ultimaUbicacion.toLatLng();
              
              // Centrar en el dispositivo seleccionado
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(devicePosition, 15.0),
                );
              }
              
              // Iniciar monitoreo en tiempo real del dispositivo seleccionado
              _startRealTimeMonitoring(result);
              
              // Agregar marcador inicial del vehículo seleccionado con icono de carro rojo
              _createVehicleIcon().then((carIcon) {
                setState(() {
                  _markers.clear(); // Limpiar todos los marcadores para ver solo un vehículo a la vez
                  _markers.add(
                    Marker(
                      markerId: const MarkerId('selected_vehicle'),
                      position: devicePosition,
                      icon: carIcon, // Usar icono de carro rojo
                      onTap: () {
                        // Mostrar BottomSheet con información del vehículo (incluye IMEI)
                        _showVehicleInfoBottomSheet(
                          devicePosition,
                          ultimaUbicacion.speed ?? result.speed,
                          result.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                          DateFormat('HH:mm:ss').format(ultimaUbicacion.timestamp),
                          imei: result.imei,
                          device: result,
                        );
                      },
                    ),
                  );
                });
              });
            } else {
              // Si no hay última ubicación, usar las coordenadas del dispositivo
              final devicePosition = LatLng(result.latitude, result.longitude);
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(devicePosition, 15.0),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              String mensajeError = 'Error de comunicación con Husat';
              if (e.toString().contains('Código:')) {
                mensajeError = e.toString().replaceFirst('Exception: ', '');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(mensajeError),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      });
    }
  }

  /// Construye la vista de perfil del usuario.
  /// 
  /// Muestra:
  /// - Avatar circular con inicial del nombre
  /// - Nombre completo
  /// - Correo electrónico
  /// - Botón para cerrar sesión
  Widget _buildProfileView() {
    final user = Provider.of<AuthProvider>(context).user;

    // Eliminar Scaffold y AppBar extra - solo retornar el contenido
    return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Avatar circular
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.red,
                child: Text(
                  user?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Nombre del usuario
              Text(
                user?.nombre ?? 'Usuario',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // Correo electrónico
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              // Botón de cerrar sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Detener rastreo antes de cerrar sesión
                    await _trackingService.stopTracking();
                    
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Construye la vista principal del mapa con Google Maps.
  /// 
  /// Incluye:
  /// - Mapa de Google Maps con punto azul nativo
  /// - Marcadores de vehículos (carros rojos)
  /// - Polyline roja del rastro (solo para clientes)
  /// - Botones flotantes: Tráfico, Centrar, Limpiar
  /// - Botón X para salir de pantalla completa
  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentPosition ?? const LatLng(-8.1116, -79.0288), // Trujillo como fallback
            zoom: 16.0,
          ),
          myLocationEnabled: true, // CRÍTICO: Activar punto azul nativo de Google (requiere permisos)
          myLocationButtonEnabled: false, // Ya tenemos nuestro botón de centrado
          padding: const EdgeInsets.only(top: 100), // Evitar que el logo de Google tape el punto azul
          markers: _getMarkers(),
          polylines: _polylines, // Mostrar polylines siempre (hoy e historial)
          mapType: MapType.normal,
          trafficEnabled: _trafficEnabled, // Capa de tráfico
        ),
        // Botón X para salir de pantalla completa
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
        // Botones flotantes: Tráfico y Centrar
        if (!_isFullScreen)
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de tráfico (widget modular)
                TrafficFab(
                  trafficEnabled: _trafficEnabled,
                  onPressed: () {
                    setState(() {
                      _trafficEnabled = !_trafficEnabled;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Botón para centrar cámara (widget modular)
                CenterLocationFab(
                  onPressed: _centerCameraOnMyLocation,
                ),
                const SizedBox(height: 12),
                // Botón de limpiar marcadores (widget modular)
                ClearMapFab(
                  onPressed: _clearMarkersAndRoute,
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  /// Limpia todos los marcadores y el rastro del mapa.
  /// 
  /// Útil para evitar saturación visual cuando hay muchos vehículos.
  /// Elimina:
  /// - Todos los marcadores de vehículos (carros rojos)
  /// - Todos los puntos del rastro de hoy (polyline roja)
  /// - Todos los puntos del historial (polyline azul)
  /// 
  /// También detiene el monitoreo en tiempo real.
  /// El punto azul nativo de Google Maps no se elimina (se maneja por separado).
  void _clearMarkersAndRoute() {
    _stopRealTimeMonitoring(); // Detener monitoreo en tiempo real
    setState(() {
      _markers.clear(); // Limpiar todos los carros rojos
      _polylinePoints.clear(); // Limpiar el rastro de hoy (roja)
      _historialPoints.clear(); // Limpiar el historial (azul)
      _historialSegments.clear(); // Limpiar segmentos del historial
      _monitoredDevice = null; // Limpiar dispositivo monitoreado
      _updatePolyline(); // Actualizar la polyline vacía
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar pantalla de carga mientras se obtiene la ubicación
    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HusatGps'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Container(
          color: Colors.red, // Pantalla roja de HusatGps
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 24),
                const Text(
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

    // Mostrar vista según el índice seleccionado
    Widget currentView;
    switch (_currentIndex) {
      case 0: // Monitor
        currentView = _buildMapView();
        break;
      case 1: // Dispositivos - Se maneja en _onBottomNavTapped
        currentView = _buildMapView(); // Temporal, se navegará
        break;
      case 2: // Alerta
        currentView = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Alertas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        break;
      case 3: // Yo (Perfil)
        currentView = _buildProfileView();
        break;
      default:
        currentView = _buildMapView();
    }

    // Si está en pantalla completa, mostrar solo el mapa sin AppBar ni BottomNav
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
      body: currentView,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.red, // Color rojo corporativo para estado activo
        unselectedItemColor: Colors.grey,
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
    );
  }

  @override
  void dispose() {
    // Cancelar timer de monitoreo estrictamente antes de cualquier otra operación
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    // Cancelar suscripción de ubicación
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    // Detener servicio de rastreo
    _trackingService.stopTracking();
    
    // Liberar controlador del mapa
    _mapController?.dispose();
    _mapController = null;
    
    super.dispose();
  }
  
  /// Inicia el monitoreo en tiempo real del dispositivo seleccionado.
  /// 
  /// Usa Timer.periodic de 10 segundos para llamar a GET /api/gps/ultima-ubicacion/{dispositivoId}
  /// Mueve el marcador del carro rojo y añade la nueva posición a la Polyline roja.
  /// Solo añade puntos si el carro se movió más de 3 metros.
  void _startRealTimeMonitoring(DeviceModel device) {
    // Detener monitoreo anterior si existe
    _stopRealTimeMonitoring();
    
    setState(() {
      _monitoredDevice = device;
      _isMonitoringRealTime = true;
      _isShowingHistorial = false;
      _historialPoints.clear(); // Limpiar historial al iniciar monitoreo en tiempo real
      _historialSegments.clear(); // Limpiar segmentos del historial
      _polylinePoints.clear(); // Limpiar ruta de hoy
    });
    
    // Cargar ubicación inicial
    _updateDeviceLocation(device);
    
    // Iniciar timer de 10 segundos
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
  
  /// Actualiza la ubicación del dispositivo desde el servidor
  Future<void> _updateDeviceLocation(DeviceModel device) async {
    try {
      final ultimaUbicacion = await GpsService.getUltimaUbicacion(device.idDispositivo.toString());
      
      if (ultimaUbicacion != null && mounted) {
        final newPosition = ultimaUbicacion.toLatLng();
        
        // Calcular distancia desde la última posición
        double distancia = 0.0;
        if (_lastTrackedPosition != null) {
          distancia = _calculateDistance(
            _lastTrackedPosition!.latitude,
            _lastTrackedPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );
        }
        
        // Solo añadir punto si se movió más de 3 metros
        if (_lastTrackedPosition == null || distancia > 3.0) {
          // Actualizar marcador del vehículo
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
                      _showVehicleInfoBottomSheet(
                        newPosition,
                        ultimaUbicacion.speed ?? device.speed,
                        device.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                        DateFormat('HH:mm:ss').format(ultimaUbicacion.timestamp),
                        imei: device.imei,
                        device: device,
                      );
                    },
                  ),
                );
                
                // Añadir punto a la polyline de hoy (roja)
                _polylinePoints.add(newPosition);
                _lastTrackedPosition = newPosition;
                _updatePolyline(); // Actualizar polyline roja
              });
            }
          });
        } else {
          // Si no se movió más de 3 metros, solo actualizar el marcador sin añadir punto
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
                      _showVehicleInfoBottomSheet(
                        newPosition,
                        ultimaUbicacion.speed ?? device.speed,
                        device.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                        DateFormat('HH:mm:ss').format(ultimaUbicacion.timestamp),
                        imei: device.imei,
                        device: device,
                      );
                    },
                  ),
                );
              });
            }
          });
        }
      }
    } catch (e) {
      // Error silencioso: se reintentará en el siguiente ciclo
    }
  }
  
  Future<void> _loadHistorial(DeviceModel device, DateTime fechaDesde, DateTime fechaHasta) async {
    _stopRealTimeMonitoring();
    
    setState(() {
      _historialPoints.clear();
      _historialSegments.clear();
      _polylinePoints.clear();
    });
    
    try {
      final historial = await GpsService.getHistorial(
        device.idDispositivo.toString(),
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );
      
      if (historial.isNotEmpty && mounted) {
        // Obtener primera y última ubicación del historial
        final primeraUbicacion = historial.first;
        final ultimaUbicacionHistorial = historial.last;
        final primeraPosicion = primeraUbicacion.toLatLng();
        final ultimaPosicion = ultimaUbicacionHistorial.toLatLng();
        
        setState(() {
          // Convertir historial a LatLng y timestamps para filtrado de saltos
          final historialPoints = <LatLng>[];
          final historialTimestamps = <DateTime>[];
          
          for (var ubicacion in historial) {
            historialPoints.add(ubicacion.toLatLng());
            historialTimestamps.add(ubicacion.timestamp);
          }
          
          // Filtrar saltos grandes (>500m) y crear segmentos continuos
          // Los saltos grandes no se dibujan, evitando líneas que atraviesan edificios
          final segments = _filterLargeJumps(historialPoints, historialTimestamps);
          
          // Guardar segmentos para crear polylines discontinuas
          _historialSegments.clear();
          _historialPoints.clear();
          
          // Interpolar cada segmento y guardarlo
          for (var segment in segments) {
            if (segment.length > 1) {
              final smoothedSegment = _interpolatePoints(segment);
              _historialSegments.add(smoothedSegment);
              // También mantener en _historialPoints para compatibilidad con fitBounds
              _historialPoints.addAll(smoothedSegment);
            }
          }
          
          // Crear iconos para marcadores
          Future.wait([
            _createStartIcon(), // Marcador verde de inicio
            _createEndIcon(), // Marcador de banderín de fin
            _createVehicleIcon(), // Marcador de vehículo
          ]).then((icons) {
            if (mounted) {
              final startIcon = icons[0] as BitmapDescriptor;
              final endIcon = icons[1] as BitmapDescriptor;
              final vehicleIcon = icons[2] as BitmapDescriptor;
              
              setState(() {
                // Limpiar marcadores anteriores (excepto mi ubicación)
                _markers.removeWhere((marker) => 
                  marker.markerId.value == 'selected_vehicle' ||
                  marker.markerId.value == 'historial_start' ||
                  marker.markerId.value == 'historial_end'
                );
                
                // Marcador de inicio (verde) en el primer punto
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
                
                // Marcador de fin (banderín) en el último punto
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
                
                // Marcador del vehículo en la última posición
                _markers.add(
                  Marker(
                    markerId: const MarkerId('selected_vehicle'),
                    position: ultimaPosicion,
                    icon: vehicleIcon,
                    onTap: () {
                      _showVehicleInfoBottomSheet(
                        ultimaPosicion,
                        ultimaUbicacionHistorial.speed ?? device.speed,
                        device.status == DeviceStatus.online ? 'En Movimiento' : 'Detenido',
                        DateFormat('HH:mm:ss').format(ultimaUbicacionHistorial.timestamp),
                        imei: device.imei,
                        device: device,
                      );
                    },
                  ),
                );
              });
            }
          });
          
          // Actualizar polyline con historial (azul) - con interpolación
          _updatePolyline();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitBoundsToRoute();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron datos para el rango de fechas seleccionado'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando historial: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// Ajusta la cámara para mostrar toda la ruta (fitBounds)
  void _fitBoundsToRoute() {
    if (_mapController == null) return;
    
    // Combinar puntos de hoy e historial
    final allPoints = <LatLng>[..._polylinePoints, ..._historialPoints];
    
    if (allPoints.isEmpty) return;
    
    // Calcular bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    
    for (var point in allPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    // Crear bounds con padding
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    // Aplicar fitBounds con padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0), // 50px de padding para mejor integración con calles
    );
  }
  
}
