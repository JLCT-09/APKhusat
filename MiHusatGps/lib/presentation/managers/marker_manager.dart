import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/models/device_model.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/services/icon_preference_service.dart';
import '../../data/gps_service.dart';

/// Variable global para almacenar devicePixelRatio (se inicializa desde MapScreen)
double? _globalDevicePixelRatio;

/// Manager que maneja toda la lógica de creación y actualización de marcadores
/// Extraído de map_screen.dart para reducir su tamaño y mejorar mantenibilidad
class MarkerManager {
  // Caché de iconos de marcadores (evita recrear iconos innecesariamente)
  // Key: 'deviceId_color_isMoving', Value: BitmapDescriptor
  final Map<String, BitmapDescriptor> _iconCache = {};
  
  // Almacenamiento de rumbo/heading para rotación del icono
  // Key: deviceId, Value: rumbo en grados (0-360)
  final Map<int, double> _deviceHeading = {};
  
  /// Establece el devicePixelRatio para calcular tamaños de iconos adaptativos
  static void setDevicePixelRatio(double devicePixelRatio) {
    _globalDevicePixelRatio = devicePixelRatio;
  }
  
  /// Obtiene el tamaño del icono calculado según la densidad de pantalla
  int _getIconSize() {
    return IconHelper.calculateIconSize(_globalDevicePixelRatio ?? 3.0);
  }
  
  /// Obtiene el rumbo/heading de un dispositivo
  double? getHeading(int deviceId) => _deviceHeading[deviceId];
  
  /// Establece el rumbo/heading de un dispositivo
  void setHeading(int deviceId, double heading) {
    _deviceHeading[deviceId] = heading;
  }
  
  /// Helper para obtener el icono según idEstadoOperativo
  /// 
  /// Mapeo directo:
  /// - idEstadoOperativo: 7 (EN MOVIMIENTO) -> carro_verde.png
  /// - idEstadoOperativo: 6 (ESTÁTICO) -> carro_azul.png
  /// - idEstadoOperativo: 4 (FUERA DE LÍNEA) -> carro_plomo.png
  /// 
  /// [stateId] - ID del estado operativo
  /// Retorna la ruta del asset PNG o null si el ID no es reconocido
  String? getIconForState(int? stateId) {
    return IconHelper.getIconForState(stateId);
  }
  
  /// Crea un icono de vehículo personalizado según el estado operativo del dispositivo
  /// 
  /// Regla: OPER_EN_MOVIMIENTO (Verde), OPER_ESTATICO (Azul), OPER_FUERA_DE_LINEA (Plomo)
  /// Si codigoEstadoOperativo es null, usa el campo "movimiento" como fallback
  /// MONITOR: Usa iconos personalizados de la carpeta "Arriba" si están disponibles, sino usa los por defecto
  Future<BitmapDescriptor> createVehicleIconWithStatus(
    DeviceModel? device, {
    Color? color,
    LatLng? currentPosition,
  }) async {
    // LÓGICA CENTRALIZADA: Usar métodos de IconHelper para determinar color y asset
    Color deviceColor;
    String? pngAssetPath;
    
    if (device != null) {
      // PRIMERO: Verificar si hay icono personalizado (para usar en monitor con carpeta Arriba)
      final iconName = await IconPreferenceService().getIconPreference(device.idDispositivo);
      if (iconName != null && iconName != 'default') {
        // Obtener ruta del icono personalizado según estado (Arriba para mapa)
        pngAssetPath = IconPreferenceService.getIconPathByState(
          iconName,
          device.idEstadoOperativo,
          isMap: true, // true = Arriba (para mapa)
        );
        
        if (pngAssetPath != null) {
          debugPrint('🎨 Monitor - Dispositivo ${device.idDispositivo}: Usando icono personalizado $iconName (${device.idEstadoOperativo}) -> $pngAssetPath');
          
          // Obtener rumbo para rotación del icono
          final heading = _deviceHeading[device.idDispositivo];
          
          try {
            // Cargar PNG desde assets con rotación (tamaño adaptativo según densidad)
            final iconSize = _getIconSize();
            final pngIcon = await IconHelper.loadPngFromAsset(
              pngAssetPath,
              size: iconSize,
              rotation: heading,
              devicePixelRatio: _globalDevicePixelRatio,
            );
            
            return pngIcon;
          } catch (e) {
            debugPrint('❌ Error al cargar icono personalizado en monitor $pngAssetPath: $e');
            // Continuar con fallback a iconos por defecto
            pngAssetPath = null;
          }
        }
      }
      
      // FALLBACK: Si no hay icono personalizado o falló, usar iconos por defecto
      // NUEVA LÓGICA: Usar idEstadoOperativo directamente (switch case)
      // Si idEstadoOperativo es null, usar fallback (velocidad/movimiento)
      if (device.idEstadoOperativo != null) {
        // Switch directo según idEstadoOperativo
        switch (device.idEstadoOperativo) {
          case 7: // EN MOVIMIENTO
            deviceColor = color ?? Colors.green;
            pngAssetPath = 'assets/images/carro_verde.png';
            break;
          case 6: // ESTÁTICO
            deviceColor = color ?? Colors.blue;
            pngAssetPath = 'assets/images/carro_azul.png';
            break;
          case 4: // FUERA DE LÍNEA
          default:
            deviceColor = color ?? Colors.grey;
            pngAssetPath = 'assets/images/carro_plomo.png';
            break;
        }
        debugPrint('🎨 Monitor - Dispositivo ${device.idDispositivo}: idEstadoOperativo=${device.idEstadoOperativo} → ${deviceColor.toString()} (icono por defecto)');
      } else {
        // FALLBACK: Si idEstadoOperativo es null, usar velocidad o movimiento
        final velocidad = device.velocidad ?? 0.0;
        final enMovimiento = device.movimiento ?? (velocidad > 0);
        
        if (enMovimiento) {
          deviceColor = color ?? Colors.green;
          pngAssetPath = 'assets/images/carro_verde.png';
        } else {
          deviceColor = color ?? Colors.blue;
          pngAssetPath = 'assets/images/carro_azul.png';
        }
        debugPrint('🎨 Monitor - Dispositivo ${device.idDispositivo}: idEstadoOperativo=null, usando fallback (velocidad=$velocidad, movimiento=${device.movimiento}) → ${deviceColor.toString()}');
      }
    } else {
      // Estado por defecto: Azul (Estático) - carro_azul.png
      deviceColor = color ?? Colors.blue;
      pngAssetPath = 'assets/images/carro_azul.png';
    }
    
    // Cargar PNG desde assets con rotación (tamaño adaptativo según densidad)
    if (device != null && pngAssetPath != null) {
      // Obtener rumbo para rotación del icono
      final heading = _deviceHeading[device.idDispositivo];
      
      // Calcular tamaño según densidad de pantalla
      final iconSize = _getIconSize();
      
      // Cargar PNG desde assets con rotación
      final pngIcon = await IconHelper.loadPngFromAsset(
        pngAssetPath,
        size: iconSize,
        rotation: heading,
        devicePixelRatio: _globalDevicePixelRatio,
      );
      
      return pngIcon;
    }
    
    // Fallback: crear icono genérico (tamaño adaptativo)
    final iconSize = _getIconSize();
    return _createFallbackIcon(device, deviceColor, iconSize);
  }
  
  /// Crea un icono de fallback (marcador de color sólido) si el PNG no se encuentra
  Future<BitmapDescriptor> _createFallbackIcon(DeviceModel? device, Color color, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final iconSize = Size(size.toDouble(), size.toDouble());
    
    // Sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(iconSize.width / 2 + 2, iconSize.height / 2 + 2),
      iconSize.width / 2,
      shadowPaint,
    );
    
    // Círculo de color sólido
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(iconSize.width / 2, iconSize.height / 2),
      iconSize.width / 2,
      circlePaint,
    );
    
    // Borde blanco
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
      Offset(iconSize.width / 2, iconSize.height / 2),
      iconSize.width / 2 - 2,
      borderPaint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(iconSize.width.toInt(), iconSize.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('No se pudo convertir el fallback a bytes');
    }
    
    final uint8List = byteData.buffer.asUint8List();
    image.dispose();
    
    debugPrint('✅ Icono de fallback creado (tamaño: ${iconSize.width}x${iconSize.height})');
    return BitmapDescriptor.fromBytes(uint8List);
  }
  
  /// Crea un marcador para un dispositivo
  /// 
  /// [device] - Dispositivo para el cual crear el marcador
  /// [position] - Posición del marcador
  /// [onTap] - Callback cuando se toca el marcador
  /// [currentPosition] - Posición actual para comparación (opcional, por defecto usa position)
  Future<Marker> createMarkerForDevice({
    required DeviceModel device,
    required LatLng position,
    required VoidCallback onTap,
    LatLng? currentPosition,
  }) async {
    // Obtener rumbo/heading para rotación del icono
    double heading = 0.0;
    if (device.rumbo != null) {
      heading = device.rumbo!;
      setHeading(device.idDispositivo, heading);
    } else {
      heading = getHeading(device.idDispositivo) ?? 0.0;
    }
    
    // Crear icono personalizado según el estado del dispositivo
    final deviceIcon = await createVehicleIconWithStatus(
      device, 
      currentPosition: currentPosition ?? position,
    );
    
    return Marker(
      markerId: MarkerId('device_${device.idDispositivo}'),
      position: position,
      icon: deviceIcon,
      rotation: heading,
      anchor: const Offset(0.5, 0.5), // CRÍTICO: Hace que el carro gire sobre su centro exacto
      flat: true, // Para que se incline con el mapa
      onTap: onTap,
    );
  }
  
  /// Crea marcadores para una lista de dispositivos
  /// 
  /// OPTIMIZACIÓN: Crea marcadores en lotes para evitar bloquear la UI con muchos dispositivos
  /// [devices] - Lista de dispositivos
  /// [onDeviceTap] - Callback cuando se toca un dispositivo (deviceId, device, position)
  /// [getDevicePosition] - Función para obtener la posición de un dispositivo
  Future<Set<Marker>> createMarkersForDevices({
    required List<DeviceModel> devices,
    required Function(int deviceId, DeviceModel device, LatLng position) onDeviceTap,
    required Future<LatLng?> Function(DeviceModel device) getDevicePosition,
  }) async {
    debugPrint('🎯 MarkerManager.createMarkersForDevices: Procesando ${devices.length} dispositivos');
    
    // OPTIMIZACIÓN: Procesar en lotes para evitar bloquear la UI
    const batchSize = 20;
    final Set<Marker> allMarkers = {};
    
    for (int i = 0; i < devices.length; i += batchSize) {
      final batchEnd = (i + batchSize > devices.length) ? devices.length : i + batchSize;
      final batch = devices.sublist(i, batchEnd);
      
      debugPrint('📦 Procesando lote ${(i ~/ batchSize) + 1}: ${batch.length} dispositivos (${i + 1}-$batchEnd de ${devices.length})');
      
      // Crear marcadores del lote en paralelo
      final markerFutures = batch.map((device) async {
      try {
        // Obtener posición del dispositivo
        final devicePosition = await getDevicePosition(device);
        if (devicePosition == null) {
          debugPrint('⚠️ Dispositivo ${device.idDispositivo}: Sin posición válida, saltando...');
          return null;
        }
        
        // Obtener rumbo/heading para rotación del icono
        double heading = 0.0;
        if (device.rumbo != null) {
          heading = device.rumbo!;
          _deviceHeading[device.idDispositivo] = heading;
        } else {
          heading = _deviceHeading[device.idDispositivo] ?? 0.0;
        }
        
        // Crear icono personalizado según el estado del dispositivo
        final deviceIcon = await createVehicleIconWithStatus(device, currentPosition: devicePosition);
        
        return Marker(
          markerId: MarkerId('device_${device.idDispositivo}'),
          position: devicePosition,
          icon: deviceIcon,
          rotation: heading,
          anchor: const Offset(0.5, 0.5), // CRÍTICO: Hace que el carro gire sobre su centro exacto
          flat: true, // Para que se incline con el mapa
          onTap: () => onDeviceTap(device.idDispositivo, device, devicePosition),
        );
      } catch (e) {
        debugPrint('❌ Error al crear marcador para dispositivo ${device.idDispositivo}: $e');
        return null;
      }
      }).toList();
      
      // Ejecutar lote en paralelo
      final batchResults = await Future.wait(markerFutures);
      final batchMarkers = batchResults.whereType<Marker>().toSet();
      allMarkers.addAll(batchMarkers);
      
      // Dar tiempo al UI thread entre lotes para mantener fluidez
      if (batchEnd < devices.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    
    debugPrint('✅ MarkerManager: Total de marcadores creados: ${allMarkers.length} de ${devices.length} dispositivos');
    return allMarkers;
  }
  
  /// Limpia el caché de iconos
  void clearIconCache() {
    _iconCache.clear();
  }
  
  /// Limpia todos los recursos
  void dispose() {
    clearIconCache();
    _deviceHeading.clear();
  }
}
