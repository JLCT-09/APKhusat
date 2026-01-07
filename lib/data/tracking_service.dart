import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/models/location_point.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Location _location = Location();
  StreamSubscription<LocationData>? _positionStream;
  final List<LocationPoint> _routeHistory = [];
  LocationPoint? _lastLocation;
  DateTime? _lastMovementTime;
  bool _isTracking = false;
  bool _isStopped = false;
  Timer? _stopDetectionTimer;

  // Callbacks
  Function(LocationPoint)? onLocationUpdate;
  Function()? onStopDetected;

  List<LocationPoint> get routeHistory => List.unmodifiable(_routeHistory);

  // Inicializar notificaciones
  Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  // Iniciar rastreo
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    // Verificar permisos
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) {
        return false;
      }
    }

    _isTracking = true;
    _routeHistory.clear();
    _lastLocation = null;
    _lastMovementTime = DateTime.now();
    _isStopped = false;

    // Mostrar notificación persistente
    await _showTrackingNotification();

    // Configurar captura de ubicación: cada 5 segundos o cada 3 metros
    _location.changeSettings(
      accuracy: LocationAccuracy.high, // Alta precisión para seguir la calle
      interval: 5000, // 5 segundos
      distanceFilter: 3.0, // 3 metros de desplazamiento
    );

    _positionStream = _location.onLocationChanged.listen(
      (LocationData locationData) {
        _handleLocationUpdate(locationData);
      },
      onError: (error) {
        debugPrint('Error en rastreo: $error');
      },
    );

    return true;
  }

  // Detener rastreo
  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    _positionStream = null;
    _stopDetectionTimer?.cancel();
    await _notifications.cancel(1);
  }

  // Calcular distancia entre dos puntos (fórmula de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // Manejar actualización de ubicación
  void _handleLocationUpdate(LocationData locationData) {
    if (locationData.latitude == null || locationData.longitude == null) {
      return;
    }

    final locationPoint = LocationPoint(
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      timestamp: DateTime.now(),
      speed: locationData.speed,
      accuracy: locationData.accuracy,
    );

    // Verificar si el vehículo se movió más de 2 metros
    if (_lastLocation != null) {
      final distance = _calculateDistance(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
        locationData.latitude!,
        locationData.longitude!,
      );

      if (distance > 2.0) {
        // Vehículo se movió más de 2 metros
        _lastMovementTime = DateTime.now();
        _isStopped = false;
        _stopDetectionTimer?.cancel();
      } else {
        // Vehículo no se ha movido más de 2 metros
        _checkForStop();
      }
    }

    // Agregar punto al historial
    _routeHistory.add(locationPoint);
    _lastLocation = locationPoint;

    // Guardar localmente
    saveLocationLocally(locationPoint);

    // Notificar actualización
    onLocationUpdate?.call(locationPoint);
  }

  // Detectar paradas
  void _checkForStop() {
    if (_lastMovementTime == null) {
      _lastMovementTime = DateTime.now();
      return;
    }

    final timeSinceLastMovement = DateTime.now().difference(_lastMovementTime!);

    if (timeSinceLastMovement.inSeconds >= 30 && !_isStopped) {
      // Parada detectada: no se movió más de 2 metros durante 30 segundos
      _isStopped = true;
      debugPrint('Estado: Detenido');
      onStopDetected?.call();
    } else if (_isStopped && timeSinceLastMovement.inSeconds < 30) {
      // Si se movió antes de los 30 segundos, resetear el estado
      _isStopped = false;
      debugPrint('Estado: En movimiento');
    }
  }

  // Mostrar notificación de rastreo activo
  Future<void> _showTrackingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'husatgps_tracking',
      'HusatGps Rastreo',
      channelDescription: 'Notificación de rastreo GPS activo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: false,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,
      'HusatGps',
      'Rastreo activo',
      notificationDetails,
    );
  }

  // Guardar ubicación localmente (simulado - listo para base de datos)
  void saveLocationLocally(LocationPoint location) {
    // Simulación: aquí se guardaría en SQLite o similar
    // Por ahora, solo mantenemos en memoria
    // En producción, usarías: await database.insert('locations', location.toJson());
    
    // Estructura lista para base de datos:
    final data = {
      'lat': location.latitude,
      'lng': location.longitude,
      'timestamp': location.timestamp.toIso8601String(),
      'speed': location.speed ?? 0.0,
      'accuracy': location.accuracy ?? 0.0,
    };
    
    // TODO: Implementar guardado real en base de datos local
    // Ejemplo con sqflite:
    // await db.insert('locations', data);
    
    debugPrint('Ubicación guardada localmente: ${data.toString()}');
  }

  // Obtener historial de ruta
  List<LocationPoint> getRouteHistory() {
    return List.unmodifiable(_routeHistory);
  }

  // Limpiar historial
  void clearHistory() {
    _routeHistory.clear();
    _lastLocation = null;
  }
}
