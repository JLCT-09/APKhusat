import 'package:flutter/foundation.dart';
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
  final bool isDataAvailable; // Indica si los datos GPS están disponibles

  GpsLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.rumbo,
    required this.timestamp,
    this.isDataAvailable = true, // Por defecto, asumimos que hay datos
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
        // CRÍTICO: El backend envía fechas en UTC (formato ISO 8601)
        // Parsear la fecha (DateTime.parse maneja automáticamente ISO 8601)
        timestamp = DateTime.parse(timestampStr);
        
        // Si no tiene zona horaria explícita (Z, +, -), asumir que está en UTC
        if (!timestampStr.contains('Z') && !timestampStr.contains('+') && !timestampStr.contains('-', 10)) {
          timestamp = timestamp.toUtc();
        }
        
        // CRÍTICO: Convertir de UTC a hora local del dispositivo
        // toLocal() maneja automáticamente la zona horaria del dispositivo
        // Esto es más preciso que restar 5 horas manualmente
        timestamp = timestamp.toLocal();
        
        debugPrint('🕐 Timestamp parseado: Backend (UTC): $timestampStr → Local: ${timestamp.toString()}');
      } catch (e) {
        debugPrint('⚠️ Error al parsear timestamp: $timestampStr, error: $e');
        // Si falla el parsing, usar fecha actual en hora local
        timestamp = DateTime.now();
      }
    } else {
      // Usar fecha actual en hora local
      timestamp = DateTime.now();
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
    
    // Validar si las coordenadas son válidas
    final isValid = !(parsedLat == 0.0 && parsedLng == 0.0) && 
                    !(parsedLat.abs() < 0.0001 && parsedLng.abs() < 0.0001);
    
    return GpsLocation(
      latitude: parsedLat,
      longitude: parsedLng,
      speed: json['velocidad'] != null ? (json['velocidad'] as num).toDouble() : null,
      rumbo: parsedRumbo,
      timestamp: timestamp,
      isDataAvailable: isValid,
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
  /// Si el servidor responde 404, retorna un GpsLocation con isDataAvailable = false.
  static Future<GpsLocation?> getUltimaUbicacion(String dispositivoId) async {
    try {
      final endpoint = ApiConfig.ultimaUbicacion(dispositivoId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        // Si no hay respuesta, retornar objeto con datos no disponibles
        return GpsLocation(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          isDataAvailable: false,
        );
      }
      
      return GpsLocation.fromJson(response);
    } catch (e) {
      // Si hay un error (incluyendo 404), retornar objeto con datos no disponibles
      // en lugar de lanzar excepción
      debugPrint('⚠️ Error al obtener ubicación GPS (puede ser 404): $e');
      return GpsLocation(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        isDataAvailable: false,
      );
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
      
      // Agregar parámetros de fecha y hora si están disponibles
      // CRÍTICO: Convertir SIEMPRE a UTC antes de enviar al backend
      // El backend espera fechas en UTC con formato ISO 8601 (con 'Z' al final)
      if (fechaDesde != null || fechaHasta != null) {
        final params = <String>[];
        if (fechaDesde != null) {
          // Convertir a UTC y formatear en ISO 8601 con 'Z' al final
          final fechaDesdeUtc = fechaDesde.toUtc();
          final desdeStr = fechaDesdeUtc.toIso8601String();
          params.add('desde=$desdeStr');
          debugPrint('📅 fechaDesde (local): ${fechaDesde.toString()} → UTC: $desdeStr');
        }
        if (fechaHasta != null) {
          // Convertir a UTC y formatear en ISO 8601 con 'Z' al final
          final fechaHastaUtc = fechaHasta.toUtc();
          final hastaStr = fechaHastaUtc.toIso8601String();
          params.add('hasta=$hastaStr');
          debugPrint('📅 fechaHasta (local): ${fechaHasta.toString()} → UTC: $hastaStr');
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
      
      debugPrint('📊 Historial recibido del backend: ${historial.length} puntos antes de ordenar');
      
      // Ordenar por fecha (más antigua primero)
      historial.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // CRÍTICO: Las fechas recibidas del backend están en hora local (ya convertidas en fromJson)
      // Las fechas de filtro (fechaDesde/fechaHasta) también están en hora local
      // Por lo tanto, podemos compararlas directamente sin conversión adicional
      debugPrint('📅 Rango de fechas solicitado (local): desde=${fechaDesde?.toString()}, hasta=${fechaHasta?.toString()}');
      
      // Aplicar búsqueda por proximidad (fuzzy dates)
      if (fechaDesde != null || fechaHasta != null) {
        // OPTIMIZACIÓN: Usar las fechas exactas proporcionadas, no expandir a todo el día
        // Esto permite buscar rangos más precisos
        final fechaDesdeInicio = fechaDesde;
        final fechaHastaFin = fechaHasta;
        
        debugPrint('📅 Filtrando por rango (local): ${fechaDesdeInicio?.toString()} a ${fechaHastaFin?.toString()}');
        debugPrint('📅 Primer punto del historial (local): ${historial.isNotEmpty ? historial.first.timestamp.toString() : "vacío"}');
        debugPrint('📅 Último punto del historial (local): ${historial.isNotEmpty ? historial.last.timestamp.toString() : "vacío"}');
        
        // Si hay fechaDesde, buscar el primer registro igual o posterior (fuzzy search)
        if (fechaDesdeInicio != null && historial.isNotEmpty) {
          // Si el primer registro es anterior a fechaDesde, buscar el primero que sea igual o posterior
          if (historial.first.timestamp.isBefore(fechaDesdeInicio)) {
            final firstValidIndex = historial.indexWhere((loc) => 
              loc.timestamp.isAfter(fechaDesdeInicio) || 
              loc.timestamp.isAtSameMomentAs(fechaDesdeInicio)
            );
            if (firstValidIndex != -1) {
              debugPrint('✂️ Eliminando ${firstValidIndex} puntos anteriores a fechaDesde');
              historial.removeRange(0, firstValidIndex);
            } else {
              // No hay registros válidos después de fechaDesde
              debugPrint('⚠️ No hay registros válidos después de fechaDesde');
              return [];
            }
          }
        }
        
        // Filtrar registros que estén fuera del rango
        final antesFiltro = historial.length;
        historial.removeWhere((ubicacion) {
          if (fechaDesdeInicio != null && ubicacion.timestamp.isBefore(fechaDesdeInicio)) {
            return true;
          }
          if (fechaHastaFin != null && ubicacion.timestamp.isAfter(fechaHastaFin)) {
            return true;
          }
          return false;
        });
        
        final despuesFiltro = historial.length;
        debugPrint('📊 Puntos después de filtrar por fecha: $despuesFiltro (${antesFiltro - despuesFiltro} eliminados)');
        
        // Si después del filtrado no hay puntos, pero había puntos antes, puede ser un problema de zona horaria
        if (despuesFiltro == 0 && antesFiltro > 0) {
          debugPrint('⚠️ ADVERTENCIA: Todos los puntos fueron filtrados. Verificando zona horaria...');
          debugPrint('   Primer punto antes del filtro: ${historial.isNotEmpty ? historial.first.timestamp.toString() : "N/A"}');
          debugPrint('   Último punto antes del filtro: ${historial.isNotEmpty ? historial.last.timestamp.toString() : "N/A"}');
          // No intentar acceder a historial.first/last si está vacío
        }
      }
      
      debugPrint('✅ Historial final: ${historial.length} puntos ordenados por timestamp');
      
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
  
  /// Obtiene el estado de múltiples dispositivos en una sola llamada (batch).
  /// 
  /// Usa GET /api/estado-dispositivo/batch?ids=1,2,3,4
  /// Retorna una lista de mapas con información de estado de cada dispositivo.
  /// Optimizado para actualizar toda la flota en el Monitor General cada 60s.
  static Future<List<Map<String, dynamic>>> getEstadoDispositivoBatch(List<int> dispositivoIds) async {
    try {
      if (dispositivoIds.isEmpty) {
        return [];
      }
      
      final endpoint = ApiConfig.estadoDispositivoBatch(dispositivoIds);
      final response = await ApiService.getList(endpoint);
      
      if (response == null || response.isEmpty) {
        return [];
      }
      
      return response.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('⚠️ Error al obtener estado batch de dispositivos: $e');
      return [];
    }
  }
  
  /// Obtiene el estado operativo de un dispositivo.
  /// 
  /// Usa GET /api/estado-dispositivo/{dispositivoId}/estado
  /// Retorna un mapa con: codigoEstadoOperativo, idEstadoOperativo
  /// Usado para actualizar el estado operativo del dispositivo en el ciclo de actualización.
  static Future<Map<String, dynamic>?> getEstadoOperativoDispositivo(String dispositivoId) async {
    try {
      final endpoint = ApiConfig.estadoOperativoDispositivo(dispositivoId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        return null;
      }
      
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ Error al obtener estado operativo del dispositivo $dispositivoId: $e');
      return null;
    }
  }
  
  /// Obtiene el estado detallado de un dispositivo (telemetría completa).
  /// 
  /// Usa GET /api/estado-dispositivo/{dispositivoId}
  /// Retorna un mapa con: bateria, energiaExterna, encendido, odometro, y fechas (con UTC-5 aplicado).
  /// Usado en el botón "Detalle" para mostrar información completa.
  static Future<Map<String, dynamic>?> getEstadoDispositivo(String dispositivoId) async {
    try {
      final endpoint = ApiConfig.estadoDispositivo(dispositivoId);
      final response = await ApiService.get(endpoint);
      
      if (response == null) {
        return null;
      }
      
      // Aplicar UTC-5 a todas las fechas del estado
      final estado = Map<String, dynamic>.from(response);
      
      // Buscar campos de fecha y aplicar UTC-5
      // TAREA 1: Incluir ultimaTramaUtc en los campos de fecha
      final dateFields = ['fechaHora', 'fecha', 'timestamp', 'fechaActualizacion', 'ultimaActualizacion', 'ultimaTramaUtc'];
      for (final field in dateFields) {
        if (estado.containsKey(field) && estado[field] != null) {
          try {
            final dateStr = estado[field].toString();
            if (dateStr.isNotEmpty) {
              DateTime date = DateTime.parse(dateStr);
              // Si no tiene zona horaria, asumir UTC
              if (!dateStr.contains('Z') && !dateStr.contains('+') && !dateStr.contains('-', 10)) {
                date = date.toUtc();
              }
              // Aplicar UTC-5 (Perú)
              date = date.subtract(const Duration(hours: 5));
              estado[field] = date.toIso8601String();
            }
          } catch (e) {
            // Ignorar errores de parsing de fechas
          }
        }
      }
      
      return estado;
    } catch (e) {
      debugPrint('⚠️ Error al obtener estado del dispositivo $dispositivoId: $e');
      return null;
    }
  }
}
