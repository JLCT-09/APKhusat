import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../core/config/api_config.dart';
import 'api_service.dart';

/// Modelo de ubicación GPS del backend
class GpsLocation {
  final double latitude;
  final double longitude;
  final double? speed; // km/h
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    required this.timestamp,
  });

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    final timestampStr = json['fecha']?.toString() ?? 
                        json['timestamp']?.toString() ?? 
                        json['fechaUbicacion']?.toString();
    
    DateTime timestamp;
    if (timestampStr != null) {
      try {
        timestamp = DateTime.parse(timestampStr);
      } catch (e) {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }
    
    // Asegurar conversión correcta de double a double (puede venir como int o double)
    final lat = json['latitud'] ?? json['latitude'];
    final lng = json['longitud'] ?? json['longitude'];
    
    return GpsLocation(
      latitude: lat != null ? (lat as num).toDouble() : 0.0,
      longitude: lng != null ? (lng as num).toDouble() : 0.0,
      speed: json['velocidad'] != null ? (json['velocidad'] as num).toDouble() : null,
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
          
          // Filtrar por fechas si se proporcionaron
          if (fechaDesde != null && ubicacion.timestamp.isBefore(fechaDesde)) {
            continue;
          }
          if (fechaHasta != null) {
            final fechaHastaFin = DateTime(fechaHasta.year, fechaHasta.month, fechaHasta.day, 23, 59, 59);
            if (ubicacion.timestamp.isAfter(fechaHastaFin)) {
              continue;
            }
          }
          
          historial.add(ubicacion);
        } catch (e) {
          // Ignorar ubicaciones con errores de parsing
        }
      }
      
      // Ordenar por fecha (más antigua primero)
      historial.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return historial;
    } catch (e) {
      return [];
    }
  }
}
