import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

/// Servicio para interactuar con Google Roads API.
/// 
/// Proporciona funcionalidad de "Snap to Roads" para ajustar puntos GPS
/// a las carreteras reales, evitando que las polylines atraviesen edificios.
class RoadsService {
  // API Key de Google Maps (debe coincidir con la del AndroidManifest.xml)
  static const String _apiKey = 'AIzaSyCCYG5f-y30dM9GDSsSvkLyhJraMtfjO5o';
  static const String _baseUrl = 'https://roads.googleapis.com/v1/snapToRoads';
  
  // Caché para puntos ya procesados (evita reenviar los mismos puntos)
  static final Map<String, List<LatLng>> _cache = {};
  
  /// Ajusta una lista de puntos GPS a las carreteras usando Google Roads API.
  /// 
  /// [points] - Lista de puntos GPS crudos a ajustar
  /// [interpolate] - Si es true, la API rellena espacios entre puntos siguiendo curvas
  /// 
  /// Retorna una lista de puntos ajustados a las carreteras, o la lista original
  /// si hay un error en la API.
  static Future<List<LatLng>> getSnappedPoints(
    List<LatLng> points, {
    bool interpolate = true,
  }) async {
    if (points.isEmpty) return points;
    
    // Crear clave de caché basada en los puntos
    final cacheKey = _generateCacheKey(points);
    if (_cache.containsKey(cacheKey)) {
      debugPrint('📦 Usando puntos desde caché');
      return _cache[cacheKey]!;
    }
    
    try {
      // Construir la URL con los puntos
      final path = points.map((p) => '${p.latitude},${p.longitude}').join('|');
      final url = Uri.parse(
        '$_baseUrl?path=$path&interpolate=$interpolate&key=$_apiKey',
      );
      
      debugPrint('🛣️ Enviando ${points.length} puntos a Google Roads API');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La API de Google Roads no respondió');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final snappedPoints = data['snappedPoints'] as List<dynamic>?;
        
        if (snappedPoints != null && snappedPoints.isNotEmpty) {
          final adjustedPoints = <LatLng>[];
          
          for (var point in snappedPoints) {
            final location = point['location'] as Map<String, dynamic>;
            final lat = (location['latitude'] as num).toDouble();
            final lng = (location['longitude'] as num).toDouble();
            adjustedPoints.add(LatLng(lat, lng));
          }
          
          // Guardar en caché
          _cache[cacheKey] = adjustedPoints;
          
          debugPrint('✅ ${adjustedPoints.length} puntos ajustados a carreteras');
          return adjustedPoints;
        } else {
          debugPrint('⚠️ La API no devolvió puntos ajustados, usando puntos originales');
          return points;
        }
      } else {
        debugPrint('❌ Error en Google Roads API: ${response.statusCode} - ${response.body}');
        return points; // Retornar puntos originales en caso de error
      }
    } catch (e) {
      debugPrint('❌ Error al procesar puntos con Google Roads API: $e');
      return points; // Retornar puntos originales en caso de error
    }
  }
  
  /// Genera una clave de caché basada en los puntos.
  /// 
  /// Usa los primeros y últimos puntos para crear una clave única
  /// que identifique si un conjunto de puntos ya fue procesado.
  static String _generateCacheKey(List<LatLng> points) {
    if (points.isEmpty) return '';
    
    // Usar el primer y último punto más el número total de puntos
    final first = points.first;
    final last = points.last;
    return '${first.latitude.toStringAsFixed(4)}_${first.longitude.toStringAsFixed(4)}_'
           '${last.latitude.toStringAsFixed(4)}_${last.longitude.toStringAsFixed(4)}_'
           '${points.length}';
  }
  
  /// Limpia la caché de puntos procesados.
  static void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Caché de Google Roads API limpiada');
  }
  
  /// Procesa puntos en lotes para evitar exceder límites de la API.
  /// 
  /// La API de Google Roads tiene un límite de 100 puntos por petición.
  /// Este método divide los puntos en lotes y los procesa secuencialmente.
  static Future<List<LatLng>> getSnappedPointsBatched(
    List<LatLng> points, {
    bool interpolate = true,
    int batchSize = 100,
  }) async {
    if (points.length <= batchSize) {
      return getSnappedPoints(points, interpolate: interpolate);
    }
    
    final allSnappedPoints = <LatLng>[];
    
    for (int i = 0; i < points.length; i += batchSize) {
      final end = (i + batchSize < points.length) ? i + batchSize : points.length;
      final batch = points.sublist(i, end);
      
      final snappedBatch = await getSnappedPoints(batch, interpolate: interpolate);
      allSnappedPoints.addAll(snappedBatch);
      
      // Pequeña pausa entre lotes para no saturar la API
      if (i + batchSize < points.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    return allSnappedPoints;
  }
}
