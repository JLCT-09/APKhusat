import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/gps_service.dart';
import '../../domain/models/device_model.dart';
import '../../core/utils/distance_helper.dart';

/// Manager que maneja toda la lógica del historial de recorridos
/// Extraído de map_screen.dart para reducir su tamaño y mejorar mantenibilidad
class HistoryManager {
  // Estado del historial
  List<GpsLocation> _playbackHistory = [];
  bool _isShowingHistorial = false;
  bool _isPlayingHistorial = false;
  int _currentPlaybackIndex = 0;
  double _playbackSpeed = 1.0;
  DeviceModel? _playbackDevice;
  Timer? _playbackTimer;
  
  // Datos del historial
  final List<LatLng> _historialPoints = [];
  final List<List<LatLng>> _historialSegments = [];
  
  // ELIMINADO: Segmentos por velocidad (rastro multicolor) - Purgado según requerimientos
  // final List<SpeedSegment> _speedSegments = [];
  
  // Puntos del historial con sus ubicaciones completas (para mostrar iconos)
  final List<GpsLocation> _historialLocations = [];
  
  // Paradas prolongadas (>2 horas) detectadas en el historial
  final List<LongStop> _longStops = [];
  
  // Getters
  List<GpsLocation> get playbackHistory => _playbackHistory;
  bool get isShowingHistorial => _isShowingHistorial;
  bool get isPlayingHistorial => _isPlayingHistorial;
  int get currentPlaybackIndex => _currentPlaybackIndex;
  List<LatLng> get historialPoints => _historialPoints;
  List<List<LatLng>> get historialSegments => _historialSegments;
  // ELIMINADO: Getter de speedSegments (purgado según requerimientos)
  // List<SpeedSegment> get speedSegments => _speedSegments;
  List<GpsLocation> get historialLocations => _historialLocations;
  List<LongStop> get longStops => _longStops;
  
  /// Carga el historial de un dispositivo
  Future<HistoryLoadResult> loadHistorial(
    DeviceModel device,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) async {
    stopPlayback();
    
    _isShowingHistorial = true;
    _isPlayingHistorial = false;
    _currentPlaybackIndex = 0;
    _historialPoints.clear();
    _historialSegments.clear();
    
    try {
      var historial = await GpsService.getHistorial(
        device.idDispositivo.toString(),
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );
      
      if (historial.isEmpty) {
        _isShowingHistorial = false;
        debugPrint('⚠️ Historial vacío para dispositivo ${device.idDispositivo} entre ${fechaDesde} y ${fechaHasta}');
        return HistoryLoadResult(
          success: false,
          message: 'No se encontraron recorridos en este horario',
        );
      }
      
      debugPrint('📊 Historial recibido: ${historial.length} puntos antes de ordenar');
      
      // CRÍTICO: Verificar el orden ANTES de ordenar para detectar si viene invertido del backend
      bool vieneInvertido = false;
      if (historial.length > 1) {
        final primerTimestampOriginal = historial.first.timestamp;
        final ultimoTimestampOriginal = historial.last.timestamp;
        debugPrint('📅 Orden original del backend: Primer punto: ${primerTimestampOriginal}, Último punto: ${ultimoTimestampOriginal}');
        
        // Si el primer timestamp es posterior al último, viene invertido del backend
        if (primerTimestampOriginal.isAfter(ultimoTimestampOriginal)) {
          debugPrint('⚠️ ADVERTENCIA: El historial viene invertido del backend, se invertirá después de ordenar');
          vieneInvertido = true;
        }
      }
      
      // IMPORTANTE: Ordenar historial por fechaHora ASCENDENTE (más antiguo primero) para asegurar continuidad
      // Esto garantiza que siempre tengamos el orden correcto independientemente de cómo venga del backend
      historial.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Si venía invertido del backend, ahora está correcto después del sort
      // Pero si el sort no funcionó correctamente, verificar y corregir
      if (historial.length > 1) {
        final primerTimestamp = historial.first.timestamp;
        final ultimoTimestamp = historial.last.timestamp;
        debugPrint('📅 Después de ordenar: Primer punto: ${primerTimestamp}, Último punto: ${ultimoTimestamp}');
        
        // Verificar que el ordenamiento sea correcto (primer timestamp debe ser anterior o igual al último)
        if (primerTimestamp.isAfter(ultimoTimestamp)) {
          debugPrint('⚠️ ERROR: El historial sigue invertido después de ordenar, invirtiendo manualmente...');
          historial = historial.reversed.toList();
          debugPrint('✅ Historial corregido: Primer punto: ${historial.first.timestamp}, Último punto: ${historial.last.timestamp}');
        } else {
          debugPrint('✅ Historial correctamente ordenado (ascendente)');
        }
      }
      
      // CRÍTICO: Asegurar orden cronológico ASCENDENTE antes de asignar a _playbackHistory
      // El historial ya está ordenado arriba, pero verificamos una vez más por seguridad
      historial.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Verificación final del orden antes de asignar
      if (historial.length > 1) {
        final primerTimestamp = historial.first.timestamp;
        final ultimoTimestamp = historial.last.timestamp;
        if (primerTimestamp.isAfter(ultimoTimestamp)) {
          debugPrint('⚠️ ERROR CRÍTICO: Historial está invertido antes de asignar a _playbackHistory, invirtiendo...');
          historial = historial.reversed.toList();
        }
      }
      
      _playbackHistory = historial;
      
      final primeraUbicacion = historial.first;
      final ultimaUbicacionHistorial = historial.last;
      final primeraPosicion = primeraUbicacion.toLatLng();
      final ultimaPosicion = ultimaUbicacionHistorial.toLatLng();
      
      debugPrint('📍 Primera posición: (${primeraPosicion.latitude}, ${primeraPosicion.longitude})');
      debugPrint('📍 Última posición: (${ultimaPosicion.latitude}, ${ultimaPosicion.longitude})');
      
      final historialPoints = <LatLng>[];
      final historialTimestamps = <DateTime>[];
      final historialLocations = <GpsLocation>[]; // Lista filtrada de ubicaciones para velocidad
      
      // OPTIMIZACIÓN: Relajar el filtrado de puntos duplicados
      // Solo filtrar si están exactamente en la misma posición (misma lat y lng con precisión de 6 decimales)
      LatLng? lastPoint;
      int puntosDuplicados = 0;
      
      for (var ubicacion in historial) {
        final currentPoint = ubicacion.toLatLng();
        
        // Solo considerar duplicado si está exactamente en la misma posición (precisión de 6 decimales)
        final isDuplicate = lastPoint != null && 
            (currentPoint.latitude.toStringAsFixed(6) == lastPoint.latitude.toStringAsFixed(6) &&
             currentPoint.longitude.toStringAsFixed(6) == lastPoint.longitude.toStringAsFixed(6));
        
        if (!isDuplicate) {
          historialPoints.add(currentPoint);
          historialTimestamps.add(ubicacion.timestamp);
          historialLocations.add(ubicacion); // Guardar ubicación para velocidad
          lastPoint = currentPoint;
        } else {
          puntosDuplicados++;
        }
      }
      
      debugPrint('📊 Puntos después de filtrar duplicados: ${historialPoints.length} (${puntosDuplicados} duplicados eliminados)');
      
      // CRÍTICO: Verificar que haya suficientes puntos después del filtrado
      // Reducir el mínimo requerido a 1 punto (solo necesita al menos 1 punto para mostrar posición)
      if (historialPoints.isEmpty) {
        _isShowingHistorial = false;
        debugPrint('❌ No hay puntos válidos después del filtrado');
        return HistoryLoadResult(
          success: false,
          message: 'No hay suficientes puntos de recorrido en este periodo',
        );
      }
      
      // Si solo hay 1 punto, aún podemos mostrarlo (aunque no habrá recorrido)
      if (historialPoints.length == 1) {
        debugPrint('⚠️ Solo hay 1 punto en el historial, se mostrará como posición estática');
      }
      
      // UNIFICACIÓN TOTAL: No segmentar, crear una lista única continua
      // Aplicar UTC-5 a todos los timestamps antes de procesar
      final historialTimestampsPeru = historialTimestamps.map((ts) => 
        ts.subtract(const Duration(hours: 5))
      ).toList();
      
      // Guardar ubicaciones completas (ya ordenadas por fechaHora)
      _historialSegments.clear();
      _historialPoints.clear();
      // ELIMINADO: _speedSegments.clear(); (purgado - no se usa rastro multicolor)
      _historialLocations.clear();
      _longStops.clear();
      
      // Guardar ubicaciones completas (ordenadas por fechaHora) - Ya filtradas sin duplicados
      _historialLocations.addAll(historialLocations);
      _historialPoints.addAll(historialPoints);
      
      // IMPORTANTE: Filtrar también _playbackHistory para eliminar puntos consecutivos idénticos
      // OPTIMIZACIÓN: Usar la misma lógica de filtrado que historialPoints (precisión de 6 decimales)
      var filteredPlaybackHistory = <GpsLocation>[];
      LatLng? lastPlaybackPosition;
      int puntosPlaybackDuplicados = 0;
      
      for (var location in historial) {
        final currentPosition = location.toLatLng();
        
        // Solo considerar duplicado si está exactamente en la misma posición (precisión de 6 decimales)
        final isDuplicate = lastPlaybackPosition != null && 
            (currentPosition.latitude.toStringAsFixed(6) == lastPlaybackPosition.latitude.toStringAsFixed(6) &&
             currentPosition.longitude.toStringAsFixed(6) == lastPlaybackPosition.longitude.toStringAsFixed(6));
        
        if (!isDuplicate) {
          filteredPlaybackHistory.add(location);
          lastPlaybackPosition = currentPosition;
        } else {
          puntosPlaybackDuplicados++;
        }
      }
      
      debugPrint('📊 Playback history después de filtrar: ${filteredPlaybackHistory.length} puntos (${puntosPlaybackDuplicados} duplicados eliminados)');
      
      // CRÍTICO: Asegurar orden cronológico ASCENDENTE (más antiguo primero) después del filtrado
      // Esto garantiza que la reproducción siempre comience desde el punto de partida (A) hacia el punto de llegada (B)
      filteredPlaybackHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Verificar orden después del sort
      if (filteredPlaybackHistory.length > 1) {
        final primerTimestampFiltrado = filteredPlaybackHistory.first.timestamp;
        final ultimoTimestampFiltrado = filteredPlaybackHistory.last.timestamp;
        debugPrint('📅 Playback history ordenado: Primer punto (A): ${primerTimestampFiltrado}, Último punto (B): ${ultimoTimestampFiltrado}');
        
        // Verificación adicional: asegurar que el primer timestamp sea anterior al último
        if (primerTimestampFiltrado.isAfter(ultimoTimestampFiltrado)) {
          debugPrint('⚠️ ERROR CRÍTICO: Playback history está invertido después del sort, invirtiendo...');
          filteredPlaybackHistory = filteredPlaybackHistory.reversed.toList();
          debugPrint('✅ Playback history corregido: Primer punto: ${filteredPlaybackHistory.first.timestamp}, Último punto: ${filteredPlaybackHistory.last.timestamp}');
        } else {
          debugPrint('✅ Playback history correctamente ordenado (ascendente: A → B)');
        }
      }
      
      _playbackHistory = filteredPlaybackHistory;
      
      // Verificar que el playback history tenga al menos 1 punto
      if (_playbackHistory.isEmpty) {
        debugPrint('⚠️ Playback history vacío después de filtrar, usando historial completo');
        _playbackHistory = historial;
        // Asegurar orden también en este caso
        _playbackHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      
      // Detectar paradas prolongadas (>2 horas) con timestamps en UTC-5
      _detectLongStops(historialLocations, historialTimestampsPeru);
      
      // Crear un solo segmento continuo (sin cortes)
      // Todos los puntos se unen en una sola lista
      // CRÍTICO: Permitir segmentos con 1 punto (para casos donde solo hay una posición)
      if (historialPoints.isNotEmpty) {
        _historialSegments.add(historialPoints); // Lista única continua
        debugPrint('✅ Segmento de historial creado con ${historialPoints.length} puntos');
      } else {
        debugPrint('⚠️ No se pudo crear segmento: historialPoints está vacío');
      }
      
      return HistoryLoadResult(
        success: true,
        startPosition: primeraPosicion,
        endPosition: ultimaPosicion,
        startTimestamp: primeraUbicacion.timestamp,
        endTimestamp: ultimaUbicacionHistorial.timestamp,
        endSpeed: ultimaUbicacionHistorial.speed,
      );
    } catch (e) {
      _isShowingHistorial = false;
      final errorMessage = e.toString().contains('404') || e.toString().contains('no encontrado')
          ? 'No se encontraron recorridos en este horario'
          : 'Error al cargar el historial. Verifique su conexión.';
      
      return HistoryLoadResult(
        success: false,
        message: errorMessage,
      );
    }
  }
  
  /// Inicia la reproducción del historial
  /// 
  /// CRÍTICO: La reproducción siempre comienza desde el índice 0 (punto más antiguo A)
  /// y avanza incrementando el índice hacia el punto más reciente (B)
  void startPlayback({
    required DeviceModel device,
    required double playbackSpeed,
    required Function(GpsLocation location, int index) onLocationUpdate,
    required Function() onComplete,
    int startIndex = 0, // Índice de inicio para continuar desde una posición
  }) {
    if (_playbackHistory.isEmpty) {
      debugPrint('⚠️ No hay historial para reproducir');
      return;
    }
    
    // CRÍTICO: Verificar y asegurar orden cronológico antes de iniciar reproducción
    if (_playbackHistory.length > 1) {
      final primerTimestamp = _playbackHistory.first.timestamp;
      final ultimoTimestamp = _playbackHistory.last.timestamp;
      
      if (primerTimestamp.isAfter(ultimoTimestamp)) {
        debugPrint('⚠️ ADVERTENCIA: _playbackHistory está invertido antes de iniciar playback, corrigiendo...');
        _playbackHistory = _playbackHistory.reversed.toList();
        debugPrint('✅ Orden corregido: Primer punto (A): ${_playbackHistory.first.timestamp}, Último punto (B): ${_playbackHistory.last.timestamp}');
      } else {
        debugPrint('✅ Orden verificado: Reproducción desde punto A (${primerTimestamp}) hacia punto B (${ultimoTimestamp})');
      }
    }
    
    stopPlayback(); // Asegurar que no hay otro playback activo
    
    _playbackDevice = device;
    _playbackSpeed = playbackSpeed;
    _isPlayingHistorial = true;
    _currentPlaybackIndex = startIndex.clamp(0, _playbackHistory.length - 1);
    
    // Log del punto inicial y final para verificación
    if (_playbackHistory.isNotEmpty) {
      final puntoInicial = _playbackHistory[_currentPlaybackIndex];
      final puntoFinal = _playbackHistory[_playbackHistory.length - 1];
      debugPrint('🎬 Iniciando reproducción:');
      debugPrint('   📍 Punto inicial (índice $_currentPlaybackIndex): ${puntoInicial.timestamp}');
      debugPrint('   📍 Punto final (índice ${_playbackHistory.length - 1}): ${puntoFinal.timestamp}');
    }
    
    final baseInterval = Duration(milliseconds: (1000 / _playbackSpeed).round());
    
    try {
      _playbackTimer = Timer.periodic(baseInterval, (timer) {
        if (_currentPlaybackIndex >= _playbackHistory.length) {
          stopPlayback();
          onComplete();
          return;
        }
        
        // CRÍTICO: Obtener ubicación del índice actual (incrementa hacia adelante: A → B)
        final location = _playbackHistory[_currentPlaybackIndex];
        onLocationUpdate(location, _currentPlaybackIndex);
        
        // CRÍTICO: Incrementar índice (NO decrementar) para avanzar del punto A al B
        _currentPlaybackIndex++;
      });
      debugPrint('✅ Playback iniciado desde índice $_currentPlaybackIndex: ${_playbackHistory.length} ubicaciones a ${_playbackSpeed}x');
    } catch (e) {
      debugPrint('❌ Error al iniciar playback: $e');
      _isPlayingHistorial = false;
      _playbackTimer = null;
    }
  }
  
  /// Detiene la reproducción del historial
  void stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlayingHistorial = false;
    _currentPlaybackIndex = 0;
  }
  
  /// Alterna entre play y pause
  void togglePlayPause({
    required DeviceModel device,
    required double playbackSpeed,
    required Function(GpsLocation location, int index) onLocationUpdate,
    required Function() onComplete,
  }) {
    if (_isPlayingHistorial) {
      stopPlayback();
    } else {
      startPlayback(
        device: device,
        playbackSpeed: playbackSpeed,
        onLocationUpdate: onLocationUpdate,
        onComplete: onComplete,
        startIndex: _currentPlaybackIndex,
      );
    }
  }
  
  /// Cambia la velocidad de reproducción
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed.clamp(1.0, 16.0);
  }
  
  /// Salta a una posición específica en el historial (0.0 a 1.0)
  /// 
  /// CRÍTICO: position 0.0 = punto más antiguo (A), position 1.0 = punto más reciente (B)
  /// El índice se calcula para avanzar del punto A hacia el punto B
  void seekTo(double position, {
    required DeviceModel device,
    required double playbackSpeed,
    required Function(GpsLocation location, int index) onLocationUpdate,
    required Function() onComplete,
  }) {
    if (_playbackHistory.isEmpty) return;
    
    // CRÍTICO: Calcular índice objetivo basado en posición (0.0 = inicio A, 1.0 = fin B)
    // position 0.0 → índice 0 (punto más antiguo)
    // position 1.0 → índice length-1 (punto más reciente)
    final targetIndex = (position * (_playbackHistory.length - 1)).round().clamp(0, _playbackHistory.length - 1);
    _currentPlaybackIndex = targetIndex;
    
    // Verificar orden antes de hacer seek
    if (_playbackHistory.length > 1 && targetIndex < _playbackHistory.length) {
      final puntoObjetivo = _playbackHistory[targetIndex];
      final primerPunto = _playbackHistory.first;
      final ultimoPunto = _playbackHistory.last;
      
      debugPrint('🎯 Seek a posición $position (índice $targetIndex):');
      debugPrint('   📍 Punto objetivo: ${puntoObjetivo.timestamp}');
      debugPrint('   📍 Primer punto (A): ${primerPunto.timestamp}');
      debugPrint('   📍 Último punto (B): ${ultimoPunto.timestamp}');
      
      // Verificar que el orden sea correcto
      if (primerPunto.timestamp.isAfter(ultimoPunto.timestamp)) {
        debugPrint('⚠️ ERROR: Orden invertido detectado en seekTo, corrigiendo...');
        _playbackHistory = _playbackHistory.reversed.toList();
        // Recalcular índice después de invertir
        _currentPlaybackIndex = (_playbackHistory.length - 1) - targetIndex;
      }
    }
    
    // Si está reproduciendo, reiniciar desde la nueva posición
    if (_isPlayingHistorial) {
      stopPlayback();
      startPlayback(
        device: device,
        playbackSpeed: playbackSpeed,
        onLocationUpdate: onLocationUpdate,
        onComplete: onComplete,
        startIndex: _currentPlaybackIndex,
      );
    } else {
      // Si está pausado, solo actualizar la ubicación visual
      if (targetIndex < _playbackHistory.length) {
        final location = _playbackHistory[_currentPlaybackIndex];
        onLocationUpdate(location, _currentPlaybackIndex);
      }
    }
  }
  
  /// Obtiene el valor del slider (0.0 a 1.0) basado en el índice actual
  /// 
  /// CRÍTICO: Maneja el caso cuando solo hay 1 punto para evitar NaN (0/0)
  double getSliderValue() {
    if (_playbackHistory.isEmpty) return 0.0;
    
    // Si solo hay 1 punto, retornar 0.0 (no hay recorrido para navegar)
    if (_playbackHistory.length <= 1) return 0.0;
    
    // Calcular progreso: indiceActual / (totalPuntos - 1)
    final progreso = _currentPlaybackIndex / (_playbackHistory.length - 1);
    
    // Sanitización defensiva: verificar NaN y asegurar rango válido
    if (progreso.isNaN || progreso.isInfinite) {
      debugPrint('⚠️ ADVERTENCIA: getSliderValue() retornó NaN o Infinity, usando 0.0');
      return 0.0;
    }
    
    // Asegurar que esté en el rango [0.0, 1.0]
    return progreso.clamp(0.0, 1.0);
  }
  
  /// Limpia todos los recursos del historial
  void clear() {
    stopPlayback();
    _isShowingHistorial = false;
    _playbackHistory.clear();
    _historialPoints.clear();
    _historialSegments.clear();
    // ELIMINADO: _speedSegments.clear(); (purgado según requerimientos)
    _playbackDevice = null;
  }
  
  /// Calcula los bounds del historial para ajustar la cámara
  LatLngBounds? getHistorialBounds() {
    if (_historialPoints.isEmpty) return null;
    
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
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  /// Filtra saltos grandes en el historial (segmentación)
  List<List<LatLng>> _filterLargeJumps(List<LatLng> points, List<DateTime>? timestamps) {
    if (points.length < 2) return [points];
    
    final segments = <List<LatLng>>[];
    var currentSegment = <LatLng>[points.first];
    
    for (int i = 1; i < points.length; i++) {
      final distance = DistanceHelper.calculateDistanceInMeters(
        currentSegment.last.latitude,
        currentSegment.last.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      
      // Si el salto es mayor a 500 metros, crear un nuevo segmento
      if (distance > 500.0) {
        if (currentSegment.length > 1) {
          segments.add(currentSegment);
        }
        currentSegment = [points[i]];
      } else {
        currentSegment.add(points[i]);
      }
    }
    
    if (currentSegment.length > 1) {
      segments.add(currentSegment);
    }
    
    return segments.isEmpty ? [points] : segments;
  }
  
  /// Interpola puntos para suavizar la línea
  List<LatLng> _interpolatePoints(List<LatLng> points) {
    if (points.length < 3) return points;
    
    final smoothed = <LatLng>[points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      // Promedio ponderado para suavizar
      final smoothedLat = (prev.latitude + curr.latitude * 2 + next.latitude) / 4;
      final smoothedLng = (prev.longitude + curr.longitude * 2 + next.longitude) / 4;
      
      smoothed.add(LatLng(smoothedLat, smoothedLng));
    }
    
    smoothed.add(points.last);
    return smoothed;
  }
  
  
  /// ELIMINADO: Método _createSpeedSegments completamente eliminado (purgado según requerimientos)
  /// ELIMINADO: Método _getSpeedColor completamente eliminado (purgado según requerimientos)
  
  /// Detecta paradas prolongadas (>2 horas) en el historial
  void _detectLongStops(List<GpsLocation> locations, List<DateTime> timestamps) {
    if (locations.length < 2 || timestamps.length < 2) return;
    
    _longStops.clear();
    
    for (int i = 1; i < locations.length; i++) {
      final prevLocation = locations[i - 1];
      final currentLocation = locations[i];
      final prevTimestamp = timestamps[i - 1];
      final currentTimestamp = timestamps[i];
      
      // Calcular diferencia de tiempo
      final timeDiff = currentTimestamp.difference(prevTimestamp);
      
      // Si la diferencia es mayor a 4 horas, es una parada prolongada
      if (timeDiff.inHours >= 4) {
        // Calcular distancia entre puntos para confirmar que es una parada (no movimiento)
        final distance = DistanceHelper.calculateDistanceInMeters(
          prevLocation.latitude,
          prevLocation.longitude,
          currentLocation.latitude,
          currentLocation.longitude,
        );
        
        // Si la distancia es menor a 100 metros, es una parada (no un salto GPS)
        if (distance < 100.0) {
          _longStops.add(LongStop(
            position: LatLng(prevLocation.latitude, prevLocation.longitude),
            startTime: prevTimestamp,
            endTime: currentTimestamp,
            duration: timeDiff,
          ));
          
          debugPrint('🛑 Parada prolongada detectada: ${timeDiff.inHours}h ${timeDiff.inMinutes % 60}m en ${prevLocation.latitude}, ${prevLocation.longitude}');
        }
      }
    }
  }

  /// Limpia recursos (timers)
  void dispose() {
    stopPlayback();
    clear();
  }
}

/// ELIMINADO: Clase SpeedSegment completamente eliminada (purgado según requerimientos)

/// Resultado de la carga del historial
class HistoryLoadResult {
  final bool success;
  final String? message;
  final LatLng? startPosition;
  final LatLng? endPosition;
  final DateTime? startTimestamp;
  final DateTime? endTimestamp;
  final double? endSpeed;
  
  HistoryLoadResult({
    required this.success,
    this.message,
    this.startPosition,
    this.endPosition,
    this.startTimestamp,
    this.endTimestamp,
    this.endSpeed,
  });
}

/// Clase para representar una parada prolongada (>2 horas) en el historial
class LongStop {
  final LatLng position;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  
  LongStop({
    required this.position,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}
