import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../core/config/api_config.dart';
import 'api_service.dart';

/// Modelo de ubicación GPS del backend
class GpsLocation {
  final double latitude;
  final double longitude;
  final double? speed; // km/h
  final double? rumbo; // Rumbo/heading en grados (0-360)
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.rumbo,
    required this.timestamp,
  });

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    // Buscar fechaHora en varios formatos posibles (prioridad: fechaHora, fecha, timestamp, fechaUbicacion)
    final timestampStr = json['fechaHora']?.toString() ?? 
                        json['fecha']?.toString() ?? 
                        json['timestamp']?.toString() ?? 
                        json['fechaUbicacion']?.toString();
    
    DateTime timestamp;
    if (timestampStr != null && timestampStr.isNotEmpty) {
      try {
        // Intentar parsear ISO 8601 con zona horaria (ej: "2024-01-15T10:30:00+00:00")
        // DateTime.parse maneja automáticamente ISO 8601 con y sin zona horaria
        timestamp = DateTime.parse(timestampStr);
        // Si no tiene zona horaria, asumir UTC
        if (!timestampStr.contains('Z') && !timestampStr.contains('+') && !timestampStr.contains('-', 10)) {
          timestamp = timestamp.toUtc();
        }
      } catch (e) {
        // Si falla el parsing, usar fecha actual
        timestamp = DateTime.now().toUtc();
      }
    } else {
      timestamp = DateTime.now().toUtc();
    }
    
    // Asegurar conversión correcta de double a double (puede venir como int o double)
    final lat = json['latitud'] ?? json['latitude'];
    final lng = json['longitud'] ?? json['longitude'];
    
    // Parsear coordenadas asegurando que sean double válidos
    double parsedLat = 0.0;
    double parsedLng = 0.0;
    
    if (lat != null) {
      try {
        parsedLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
      } catch (e) {
        parsedLat = 0.0;
      }
    }
    
    if (lng != null) {
      try {
        parsedLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;
      } catch (e) {
        parsedLng = 0.0;
      }
    }
    
    // Parsear rumbo/heading si está disponible
    double? parsedRumbo;
    if (json['rumbo'] != null || json['heading'] != null) {
      try {
        final rumboValue = json['rumbo'] ?? json['heading'];
        parsedRumbo = (rumboValue is num) ? rumboValue.toDouble() : double.tryParse(rumboValue.toString());
      } catch (e) {
        parsedRumbo = null;
      }
    }
    
    return GpsLocation(
      latitude: parsedLat,
      longitude: parsedLng,
      speed: json['velocidad'] != null ? (json['velocidad'] as num).toDouble() : null,
      rumbo: parsedRumbo,
      timestamp: timestamp,
    );
  }
  
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

/// Servicio para obtener información GPS desde el backend.
/// 
/// Obtiene la última ubicación y el historial de un dispositivo.
class GpsService {
  /// Obtiene la última ubicación registrada de un dispositivo.
  /// 
  /// Usa GET /api/gps/ultima-ubicacion/{dispositivoId}
  /// Retorna un GpsLocation con la posición más reciente.
  static Future<GpsLocation?> getUltimaUbicacion(String dispositivoId) async {
    try {
      final endpoint = ApiConfig.ultimaUbicacion(dispositivoId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        return null;
      }
      
      return GpsLocation.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  /// Obtiene la última ubicación real de un dispositivo por ID.
  /// 
  /// Esta función es un alias de getUltimaUbicacion pero acepta int directamente.
  /// Regla de Oro: Siempre que la latitud/longitud sea 0.0, usar este endpoint.
  static Future<GpsLocation?> fetchLastLocation(int id) async {
    return getUltimaUbicacion(id.toString());
  }
  
  /// Obtiene el historial de ubicaciones de un dispositivo.
  /// 
  /// Usa GET /api/gps/historial/{dispositivoId}
  /// Opcionalmente filtra por rango de fechas usando parámetros 'desde' y 'hasta'.
  /// Retorna una lista de GpsLocation ordenada por fecha (más antigua primero).
  static Future<List<GpsLocation>> getHistorial(
    String dispositivoId, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    try {
      String endpoint = ApiConfig.historialGps(dispositivoId);
      
      // Agregar parámetros de fecha si están disponibles
      // IMPORTANTE: Los parámetros deben ser 'desde' y 'hasta' (no 'fechaDesde' y 'fechaHasta')
      if (fechaDesde != null || fechaHasta != null) {
        final params = <String>[];
        if (fechaDesde != null) {
          // Formato yyyy-MM-dd (sin horas)
          params.add('desde=${DateFormat('yyyy-MM-dd').format(fechaDesde)}');
        }
        if (fechaHasta != null) {
          // Formato yyyy-MM-dd (sin horas)
          params.add('hasta=${DateFormat('yyyy-MM-dd').format(fechaHasta)}');
        }
        if (params.isNotEmpty) {
          endpoint += '?${params.join('&')}';
        }
      }
      
      final response = await ApiService.getList(endpoint);
      
      if (response == null || response.isEmpty) {
        return [];
      }
      
      final historial = <GpsLocation>[];
      
      for (var item in response) {
        try {
          final ubicacion = GpsLocation.fromJson(item as Map<String, dynamic>);
          
          // Validar coordenadas antes de añadir
          if (!_isValidCoordinate(ubicacion.latitude, ubicacion.longitude)) {
            continue;
          }
          
          historial.add(ubicacion);
        } catch (e) {
          // Ignorar ubicaciones con errores de parsing
        }
      }
      
      // Ordenar por fecha (más antigua primero)
      historial.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Aplicar búsqueda por proximidad (fuzzy dates)
      if (fechaDesde != null || fechaHasta != null) {
        final fechaDesdeInicio = fechaDesde != null 
            ? DateTime(fechaDesde.year, fechaDesde.month, fechaDesde.day, 0, 0, 0)
            : null;
        final fechaHastaFin = fechaHasta != null
            ? DateTime(fechaHasta.year, fechaHasta.month, fechaHasta.day, 23, 59, 59)
            : null;
        
        // Si hay fechaDesde, buscar el primer registro igual o posterior (fuzzy search)
        if (fechaDesdeInicio != null && historial.isNotEmpty) {
          // Si el primer registro es anterior a fechaDesde, buscar el primero que sea igual o posterior
          if (historial.first.timestamp.isBefore(fechaDesdeInicio)) {
            final firstValidIndex = historial.indexWhere((loc) => 
              loc.timestamp.isAfter(fechaDesdeInicio) || 
              loc.timestamp.isAtSameMomentAs(fechaDesdeInicio)
            );
            if (firstValidIndex != -1) {
              historial.removeRange(0, firstValidIndex);
            } else {
              // No hay registros válidos después de fechaDesde
              return [];
            }
          }
        }
        
        // Filtrar registros que estén fuera del rango
        historial.removeWhere((ubicacion) {
          if (fechaDesdeInicio != null && ubicacion.timestamp.isBefore(fechaDesdeInicio)) {
            return true;
          }
          if (fechaHastaFin != null && ubicacion.timestamp.isAfter(fechaHastaFin)) {
            return true;
          }
          return false;
        });
      }
      
      return historial;
    } catch (e) {
      return [];
    }
  }
  
  /// Valida si una coordenada es válida (no es 0.0, 0.0)
  static bool _isValidCoordinate(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }
}
