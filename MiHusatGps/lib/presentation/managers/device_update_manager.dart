import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/device_model.dart';
import '../../data/gps_service.dart';
import '../../data/device_service.dart';
import '../../core/utils/storage_service.dart';

/// Manager que maneja la lógica de actualización de dispositivos
/// Extraído de map_screen.dart para reducir su tamaño y mejorar mantenibilidad
/// 
/// Gestiona:
/// - Timer de actualización automática (10 segundos)
/// - Actualización manual desde botón
/// - Batch de estado de dispositivos
class DeviceUpdateManager {
  Timer? _updateCounterTimer;
  Timer? _refreshTimer;
  int _countdownSeconds = 10;
  bool _isManualRefreshing = false;
  
  // OPTIMIZACIÓN: Límite de concurrencia para llamadas API (evita sobrecargar servidor)
  static const int _maxConcurrency = 10;
  
  // Callbacks
  Function(List<DeviceModel>)? onDevicesUpdated;
  Function(int countdown)? onCountdownChanged;
  Function(bool isRefreshing)? onRefreshStateChanged;
  Function()? onAutoRefreshTriggered; // Callback cuando el contador llega a 0
  
  /// Inicia el contador regresivo de actualización (10 → 1 segundo)
  void startUpdateCounter() {
    _countdownSeconds = 10;
    _updateCounterTimer?.cancel();
    
    _updateCounterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      onCountdownChanged?.call(_countdownSeconds);
      
      if (_countdownSeconds <= 0) {
        timer.cancel();
        // Disparar callback para que el componente padre ejecute la actualización
        onAutoRefreshTriggered?.call();
      }
    });
  }
  
  /// Reinicia el contador regresivo a 10
  void resetUpdateCounter() {
    _countdownSeconds = 10;
    _updateCounterTimer?.cancel();
    _updateCounterTimer = null;
    // Notificar el cambio antes de iniciar el nuevo timer
    onCountdownChanged?.call(_countdownSeconds);
    startUpdateCounter();
  }
  
  /// Detiene el contador de actualización
  void stopUpdateCounter() {
    _updateCounterTimer?.cancel();
    _updateCounterTimer = null;
  }
  
  /// Obtiene el contador actual
  int get countdownSeconds => _countdownSeconds;
  
  /// Verifica si está refrescando manualmente
  bool get isManualRefreshing => _isManualRefreshing;
  
  /// Realiza la actualización automática usando API individual
  /// 
  /// Usa GET /api/estado-dispositivo/{idDispositivo} para cada dispositivo individualmente
  /// Extrae: latitud, longitud, rumbo de cada respuesta
  /// Usa Future.wait() para paralelizar las llamadas y mejorar rendimiento
  Future<List<DeviceModel>> performAutoRefresh(List<DeviceModel> currentDevices) async {
    if (currentDevices.isEmpty) {
      return currentDevices;
    }
    
    try {
      debugPrint('🔄 Actualización automática: Consultando /api/estado-dispositivo/{id} para ${currentDevices.length} dispositivos');
      
      // Crear lista de futures para ejecutar en paralelo
      final futures = currentDevices.map((device) async {
        try {
          // Llamar a /api/estado-dispositivo/{idDispositivo} para obtener datos frescos
          final estado = await GpsService.getEstadoDispositivo(device.idDispositivo.toString());
          
          if (estado != null) {
            // CRÍTICO: Extraer latitud, longitud y rumbo de la respuesta
            double? latFromEstado;
            double? lngFromEstado;
            double? rumboFromEstado;
            
            // Extraer latitud
            final lat = estado['latitud'] ?? estado['latitude'];
            if (lat != null) {
              final parsedLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
              if (parsedLat != null && parsedLat != 0.0) {
                latFromEstado = parsedLat;
              }
            }
            
            // Extraer longitud
            final lng = estado['longitud'] ?? estado['longitude'];
            if (lng != null) {
              final parsedLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
              if (parsedLng != null && parsedLng != 0.0) {
                lngFromEstado = parsedLng;
              }
            }
            
            // CRÍTICO: Extraer rumbo
            final rumbo = estado['rumbo'] ?? estado['heading'];
            if (rumbo != null) {
              final parsedRumbo = (rumbo is num) ? rumbo.toDouble() : double.tryParse(rumbo.toString());
              if (parsedRumbo != null) {
                rumboFromEstado = parsedRumbo;
              }
            }
            
            // Verificar si las coordenadas cambiaron
            final coordenadasCambiaron = (latFromEstado != null && lngFromEstado != null) &&
                (latFromEstado != device.latitude || lngFromEstado != device.longitude);
            
            if (coordenadasCambiaron) {
              debugPrint('📍 [Auto] Coordenadas cambiaron para dispositivo ${device.idDispositivo}: (${device.latitude}, ${device.longitude}) → (${latFromEstado}, ${lngFromEstado})');
            }
            
            // Extraer otros campos del JSON
            final movimientoValue = estado['movimiento'];
            final movimientoBool = movimientoValue != null 
                ? (movimientoValue is bool ? movimientoValue : (movimientoValue.toString().toLowerCase() == 'true'))
                : device.movimiento;
            
            final velocidad = estado['velocidad'] != null
                ? ((estado['velocidad'] is num) 
                    ? estado['velocidad'].toDouble() 
                    : double.tryParse(estado['velocidad'].toString()))
                : device.speed;
            
            final bateria = estado['bateria'] != null
                ? ((estado['bateria'] is num) 
                    ? estado['bateria'].toInt() 
                    : int.tryParse(estado['bateria'].toString()))
                : device.bateria;
            
            final energiaExterna = estado['energiaExterna'] != null
                ? ((estado['energiaExterna'] is num) 
                    ? estado['energiaExterna'].toDouble() 
                    : double.tryParse(estado['energiaExterna'].toString()))
                : device.voltajeExterno;
            
            // Obtener estado operativo del dispositivo (llamada paralela)
            Map<String, dynamic>? estadoOperativo;
            try {
              estadoOperativo = await GpsService.getEstadoOperativoDispositivo(device.idDispositivo.toString());
            } catch (e) {
              debugPrint('⚠️ Error al obtener estado operativo para dispositivo ${device.idDispositivo}: $e');
            }
            
            // Crear nuevo DeviceModel con datos actualizados
            final updatedDevice = DeviceModel(
              idDispositivo: device.idDispositivo,
              nombre: device.nombre,
              imei: device.imei,
              placa: device.placa,
              usuarioId: device.usuarioId,
              nombreUsuario: device.nombreUsuario,
              status: device.status,
              latitude: latFromEstado ?? device.latitude, // CRÍTICO: Usar coordenadas de /api/estado-dispositivo/{id}
              longitude: lngFromEstado ?? device.longitude, // CRÍTICO: Usar coordenadas de /api/estado-dispositivo/{id}
              speed: velocidad ?? device.speed,
              lastUpdate: device.lastUpdate,
              voltaje: device.voltaje,
              voltajeExterno: energiaExterna ?? device.voltajeExterno,
              kilometrajeTotal: device.kilometrajeTotal,
              bateria: bateria ?? device.bateria,
              estadoMotor: estado['encendido'] ?? device.estadoMotor,
              movimiento: movimientoBool,
              rumbo: rumboFromEstado ?? device.rumbo, // CRÍTICO: Usar rumbo de /api/estado-dispositivo/{id}
              modeloGps: device.modeloGps,
              tipo: device.tipo,
              fechaVencimiento: device.fechaVencimiento,
              idEstado: estado['idEstado'] ?? device.idEstado,
              codigoEstadoOperativo: estadoOperativo?['codigoEstadoOperativo'] ?? estado['codigoEstadoOperativo'] ?? device.codigoEstadoOperativo,
              idEstadoOperativo: estadoOperativo?['idEstadoOperativo'] ?? estado['idEstadoOperativo'] ?? device.idEstadoOperativo,
            );
            
            debugPrint('✅ [Auto] Dispositivo ${device.idDispositivo}: coordenadas=(${updatedDevice.latitude}, ${updatedDevice.longitude}), rumbo=${updatedDevice.rumbo}, velocidad=$velocidad');
            
            return updatedDevice;
          } else {
            // Si no hay estado, mantener el dispositivo original
            return device;
          }
        } catch (e) {
          debugPrint('⚠️ Error al actualizar dispositivo ${device.idDispositivo}: $e');
          return device;
        }
      }).toList();
      
      // OPTIMIZACIÓN: Ejecutar llamadas con límite de concurrencia para evitar sobrecargar servidor
      final updatedDevices = await _executeWithConcurrencyLimit(futures, _maxConcurrency);
      
      debugPrint('✅ Actualización automática completada: ${updatedDevices.length} dispositivos actualizados desde /api/estado-dispositivo/{id}');
      return updatedDevices;
    } catch (e) {
      debugPrint('❌ Error en actualización automática: $e');
      return currentDevices;
    }
  }
  
  
  /// Realiza la actualización manual desde el botón
  /// 
  /// Usa GET /api/estado-dispositivo/{id} para cada dispositivo individualmente
  /// También llama a GET /api/estado-dispositivo/{id}/estado para estado operativo
  /// Si currentDevices está vacío, carga la lista inicial desde DeviceService
  /// 
  /// [usuarioIdObjetivo] - ID opcional del usuario objetivo para filtro de supervisión (solo admins)
  Future<List<DeviceModel>> performManualRefresh(
    List<DeviceModel> currentDevices, {
    int? usuarioIdObjetivo,
  }) async {
    if (_isManualRefreshing) {
      debugPrint('⚠️ Ya se está refrescando, ignorando llamada');
      return currentDevices;
    }
    
    _isManualRefreshing = true;
    onRefreshStateChanged?.call(true);
    
    try {
      // CRÍTICO: Si la lista está vacía o hay un filtro de supervisión, cargar dispositivos
      if (currentDevices.isEmpty || usuarioIdObjetivo != null) {
        debugPrint('📥 ${usuarioIdObjetivo != null ? 'Filtro de supervisión activo' : 'Lista vacía'}, cargando dispositivos desde DeviceService...');
        try {
          final userId = await StorageService.getUserId();
          if (userId == null || userId.isEmpty) {
            debugPrint('❌ No se pudo obtener userId para cargar dispositivos');
            return currentDevices;
          }
          
          final dispositivos = await DeviceService.getDispositivosPorUsuario(
            userId,
            usuarioIdObjetivo: usuarioIdObjetivo,
          );
          debugPrint('✅ Cargados ${dispositivos.length} dispositivos desde DeviceService${usuarioIdObjetivo != null ? ' (Usuario objetivo: $usuarioIdObjetivo)' : ''}');
          
          if (dispositivos.isEmpty) {
            debugPrint('⚠️ No hay dispositivos para el usuario');
            return currentDevices;
          }
          
          // Actualizar la lista con los dispositivos cargados
          currentDevices = dispositivos;
        } catch (e) {
          debugPrint('❌ Error al cargar dispositivos iniciales: $e');
          return currentDevices;
        }
      }
      
      debugPrint('🔄 Actualización manual: Consultando /api/estado-dispositivo/{id} para ${currentDevices.length} dispositivos (PARALELIZADO)');
      
      // OPTIMIZACIÓN: Paralelizar todas las llamadas usando Future.wait()
      final futures = currentDevices.map((device) async {
        try {
          // Llamar a /api/estado-dispositivo/{id} para obtener datos frescos
          final estado = await GpsService.getEstadoDispositivo(device.idDispositivo.toString());
          
          if (estado != null) {
            // Extraer coordenadas del estado
            double? latFromEstado;
            double? lngFromEstado;
            final lat = estado['latitud'] ?? estado['latitude'];
            final lng = estado['longitud'] ?? estado['longitude'];
            
            if (lat != null && lng != null) {
              final parsedLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
              final parsedLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
              
              if (parsedLat != null && parsedLng != null) {
                latFromEstado = parsedLat;
                lngFromEstado = parsedLng;
              }
            }
            
            // Extraer campos del JSON
            final movimientoValue = estado['movimiento'];
            final movimientoBool = movimientoValue != null 
                ? (movimientoValue is bool ? movimientoValue : (movimientoValue.toString().toLowerCase() == 'true'))
                : device.movimiento;
            
            final velocidad = estado['velocidad'] != null
                ? ((estado['velocidad'] is num) 
                    ? estado['velocidad'].toDouble() 
                    : double.tryParse(estado['velocidad'].toString()))
                : device.speed;
            
            final bateria = estado['bateria'] != null
                ? ((estado['bateria'] is num) 
                    ? estado['bateria'].toInt() 
                    : int.tryParse(estado['bateria'].toString()))
                : device.bateria;
            
            final energiaExterna = estado['energiaExterna'] != null
                ? ((estado['energiaExterna'] is num) 
                    ? estado['energiaExterna'].toDouble() 
                    : double.tryParse(estado['energiaExterna'].toString()))
                : device.voltajeExterno;
            
            final rumbo = estado['rumbo'] ?? estado['heading'];
            final heading = (rumbo != null) 
                ? ((rumbo is num) ? rumbo.toDouble() : double.tryParse(rumbo.toString()))
                : null;
            
            // Obtener estado operativo del dispositivo (llamada paralela)
            Map<String, dynamic>? estadoOperativo;
            try {
              estadoOperativo = await GpsService.getEstadoOperativoDispositivo(device.idDispositivo.toString());
              if (estadoOperativo != null) {
                debugPrint('📊 Estado Operativo - Dispositivo ${device.idDispositivo}: codigo=${estadoOperativo['codigoEstadoOperativo']}, id=${estadoOperativo['idEstadoOperativo']}');
              }
            } catch (e) {
              debugPrint('⚠️ Error al obtener estado operativo para dispositivo ${device.idDispositivo}: $e');
            }
            
            // Crear nuevo DeviceModel con datos actualizados
            final updatedDevice = DeviceModel(
              idDispositivo: device.idDispositivo,
              nombre: device.nombre,
              imei: device.imei,
              placa: device.placa,
              usuarioId: device.usuarioId,
              nombreUsuario: device.nombreUsuario,
              status: device.status,
              latitude: latFromEstado ?? device.latitude,
              longitude: lngFromEstado ?? device.longitude,
              speed: velocidad ?? device.speed,
              lastUpdate: device.lastUpdate,
              voltaje: device.voltaje,
              voltajeExterno: energiaExterna ?? device.voltajeExterno,
              kilometrajeTotal: device.kilometrajeTotal,
              bateria: bateria ?? device.bateria,
              estadoMotor: estado['encendido'] ?? device.estadoMotor,
              movimiento: movimientoBool,
              rumbo: heading ?? device.rumbo,
              modeloGps: device.modeloGps,
              tipo: device.tipo,
              fechaVencimiento: device.fechaVencimiento,
              idEstado: estado['idEstado'] ?? device.idEstado,
              codigoEstadoOperativo: estadoOperativo?['codigoEstadoOperativo'] ?? estado['codigoEstadoOperativo'] ?? device.codigoEstadoOperativo,
              idEstadoOperativo: estadoOperativo?['idEstadoOperativo'] ?? estado['idEstadoOperativo'] ?? device.idEstadoOperativo,
            );
            
            return updatedDevice;
          } else {
            // Si no hay estado, mantener el dispositivo original
            return device;
          }
        } catch (e) {
          debugPrint('⚠️ Error al actualizar dispositivo ${device.idDispositivo}: $e');
          return device;
        }
      }).toList();
      
      // OPTIMIZACIÓN: Ejecutar llamadas con límite de concurrencia para evitar sobrecargar servidor
      final updatedDevices = await _executeWithConcurrencyLimit(futures, _maxConcurrency);
      
      debugPrint('✅ Actualización manual completada: ${updatedDevices.length} dispositivos actualizados (con límite de concurrencia: $_maxConcurrency)');
      return updatedDevices;
    } finally {
      _isManualRefreshing = false;
      onRefreshStateChanged?.call(false);
    }
  }
  
  /// Ejecuta una lista de futures con límite de concurrencia
  /// 
  /// OPTIMIZACIÓN: Evita sobrecargar el servidor ejecutando solo un número limitado
  /// de llamadas simultáneas. Procesa en lotes.
  /// 
  /// [futures] - Lista de futures a ejecutar
  /// [maxConcurrency] - Número máximo de llamadas simultáneas
  /// Retorna lista de resultados en el mismo orden
  Future<List<T>> _executeWithConcurrencyLimit<T>(
    List<Future<T>> futures,
    int maxConcurrency,
  ) async {
    if (futures.isEmpty) return [];
    
    final results = <T>[];
    
    // Procesar en lotes
    for (int i = 0; i < futures.length; i += maxConcurrency) {
      final batchEnd = (i + maxConcurrency > futures.length) 
          ? futures.length 
          : i + maxConcurrency;
      final batch = futures.sublist(i, batchEnd);
      
      // Ejecutar lote en paralelo
      final batchResults = await Future.wait(batch);
      results.addAll(batchResults);
      
      // Pequeño delay entre lotes para no saturar el servidor
      if (batchEnd < futures.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    
    return results;
  }
  
  /// Limpia todos los recursos
  void dispose() {
    stopUpdateCounter();
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
