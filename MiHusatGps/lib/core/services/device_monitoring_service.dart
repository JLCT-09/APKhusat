import 'dart:async';
import '../../data/device_service.dart';
import '../../data/gps_service.dart';
import '../../core/utils/storage_service.dart';
import 'alert_service.dart';

/// Servicio para monitorear todos los dispositivos en segundo plano.
/// 
/// Verifica periódicamente el estado de cobertura de todos los dispositivos
/// y dispara alertas cuando sea necesario.
class DeviceMonitoringService {
  static final DeviceMonitoringService _instance = DeviceMonitoringService._internal();
  factory DeviceMonitoringService() => _instance;
  DeviceMonitoringService._internal();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// Inicia el monitoreo de todos los dispositivos
  /// 
  /// Verifica cada 30 segundos el estado de cobertura de todos los dispositivos
  /// y dispara alertas si es necesario.
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return; // Ya está monitoreando
    }

    _isMonitoring = true;

    // Verificar inmediatamente
    await _checkAllDevices();

    // Configurar timer para verificar cada 30 segundos
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isMonitoring) {
        await _checkAllDevices();
      } else {
        timer.cancel();
      }
    });
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Verifica todos los dispositivos del usuario para alertas de cobertura
  Future<void> _checkAllDevices() async {
    try {
      // Obtener ID del usuario
      final userId = await StorageService.getUserId();
      if (userId == null || userId.isEmpty) {
        return; // No hay usuario logueado
      }

      // Obtener todos los dispositivos del usuario
      final devices = await DeviceService.getDispositivosPorUsuario(userId);

      // Verificar cada dispositivo individualmente
      for (final device in devices) {
        try {
          // Obtener última ubicación del dispositivo
          final ultimaUbicacion = await GpsService.getUltimaUbicacion(
            device.idDispositivo.toString(),
          );

          // Verificar alerta de cobertura usando la fechaHora del dispositivo
          // Si no hay última ubicación, usar la fechaHora del dispositivo directamente
          DateTime? lastUpdate;
          
          if (ultimaUbicacion != null) {
            lastUpdate = ultimaUbicacion.timestamp;
          } else {
            // Si no hay última ubicación, intentar obtener del historial más reciente
            try {
              final historial = await GpsService.getHistorial(
                device.idDispositivo.toString(),
                fechaDesde: DateTime.now().subtract(const Duration(hours: 1)),
                fechaHasta: DateTime.now(),
              );
              
              if (historial.isNotEmpty) {
                // Ordenar por fecha más reciente
                historial.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                lastUpdate = historial.first.timestamp;
              }
            } catch (e) {
              // Si no se puede obtener historial, continuar con el siguiente dispositivo
              continue;
            }
          }

          // Verificar alerta de cobertura para este dispositivo
          if (lastUpdate != null) {
            await AlertService().checkCoverageAlert(device, lastUpdate);
          }
        } catch (e) {
          // Continuar con el siguiente dispositivo si hay error
          continue;
        }
      }
    } catch (e) {
      // Error silencioso - no queremos que falle el monitoreo
    }
  }

  /// Verifica si el monitoreo está activo
  bool get isMonitoring => _isMonitoring;
}
