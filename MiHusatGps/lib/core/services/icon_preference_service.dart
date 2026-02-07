import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Servicio para gestionar iconos personalizados por dispositivo
/// 
/// Almacena las preferencias de iconos usando SharedPreferences
/// Formato: 'icon_device_{idDispositivo}' -> 'nombre_icono'
class IconPreferenceService {
  static final IconPreferenceService _instance = IconPreferenceService._internal();
  factory IconPreferenceService() => _instance;
  IconPreferenceService._internal();

  static const String _prefix = 'icon_device_';
  
  // Notifier para notificar cambios en iconos (para actualizar lista de dispositivos)
  final ValueNotifier<int?> iconChangedNotifier = ValueNotifier<int?>(null);
  
  /// Iconos disponibles para seleccionar (PNG desde assets/Iconos/Iconos/Lateral/Gris)
  /// Los iconos descriptivos tienen variantes en Verde, Azul y Offline según el estado del dispositivo
  static const List<Map<String, dynamic>> availableIcons = [
    // === ICONOS DESCRIPTIVOS (con variantes en múltiples colores) ===
    {'name': 'Auto', 'label': 'Auto', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Auto.png'},
    {'name': 'AutoBus', 'label': 'Autobús', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/AutoBus.png'},
    {'name': 'Barco', 'label': 'Barco', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Barco.png'},
    {'name': 'Camion', 'label': 'Camión', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Camion.png'},
    {'name': 'CamionBasura', 'label': 'Camión Basura', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/CamionBasura.png'},
    {'name': 'Camioneta', 'label': 'Camioneta', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Camioneta.png'},
    {'name': 'Cisterna', 'label': 'Cisterna', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Cisterna.png'},
    {'name': 'Comun', 'label': 'Común', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Comun.png'},
    {'name': 'Elevadora', 'label': 'Elevadora', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Elevadora.png'},
    {'name': 'Excavadora', 'label': 'Excavadora', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Excavadora.png'},
    {'name': 'Flecha', 'label': 'Flecha', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Flecha.png'},
    {'name': 'Grua', 'label': 'Grúa', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Grua.png'},
    {'name': 'Mascota', 'label': 'Mascota', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Mascota.png'},
    {'name': 'MontaCarga', 'label': 'Montacarga', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/MontaCarga.png'},
    {'name': 'Moto', 'label': 'Moto', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Moto.png'},
    {'name': 'MotoTaxi', 'label': 'Moto Taxi', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/MotoTaxi.png'},
    {'name': 'Mpv', 'label': 'MPV', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Mpv.png'},
    {'name': 'Persona', 'label': 'Persona', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Persona.png'},
    {'name': 'Remolque', 'label': 'Remolque', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Remolque.png'},
    {'name': 'Revolvedora', 'label': 'Revolvedora', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Revolvedora.png'},
    {'name': 'Suv', 'label': 'SUV', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Suv.png'},
    {'name': 'Taxi', 'label': 'Taxi', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Taxi.png'},
    {'name': 'Tractor', 'label': 'Tractor', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Tractor.png'},
    {'name': 'Trailer', 'label': 'Trailer', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Trailer.png'},
    {'name': 'Van', 'label': 'Van', 'assetPath': 'assets/Iconos/Iconos/Lateral/Gris/Van.png'},
  ];

  /// Extrae el nombre base del icono desde una ruta completa
  /// Ejemplo: 'assets/Iconos/Lateral/Gris/Carro.png' -> 'Carro'
  static String extractIconBaseName(String? iconPathOrName) {
    if (iconPathOrName == null || iconPathOrName.isEmpty || iconPathOrName == 'default') {
      return 'default';
    }
    
    // Si ya es solo el nombre (sin ruta), retornarlo
    if (!iconPathOrName.contains('/')) {
      return iconPathOrName;
    }
    
    // Extraer nombre del archivo sin extensión
    final fileName = iconPathOrName.split('/').last;
    return fileName.replaceAll('.png', '');
  }

  /// Obtiene el nombre de la carpeta de color según el estado operativo
  /// 
  /// [idEstadoOperativo] - ID del estado operativo
  /// [isMap] - Si es true, usa carpetas "Arriba", si es false usa "Lateral"
  /// Retorna el nombre de la carpeta de color
  static String _getColorFolderByState(int? idEstadoOperativo, {bool isMap = false}) {
    // Estructura real: assets/Iconos/Iconos/Lateral o assets/Iconos/Iconos/Arriba
    final basePath = isMap ? 'assets/Iconos/Iconos/Arriba' : 'assets/Iconos/Iconos/Lateral';
    
    switch (idEstadoOperativo) {
      case 7: // EN MOVIMIENTO -> Verde
        return '$basePath/Verde';
      case 6: // ESTÁTICO -> Azul
        return '$basePath/Azul';
      case 4: // FUERA DE LÍNEA -> Offline
        return '$basePath/Offline';
      default:
        // Fallback: Gris (solo para Lateral, para Arriba usar Offline)
        return isMap ? '$basePath/Offline' : '$basePath/Gris';
    }
  }

  /// Obtiene la ruta del asset PNG según el nombre del icono y estado operativo
  /// 
  /// [iconName] - Nombre base del icono (ej: 'Carro', '3p', 'default')
  /// [idEstadoOperativo] - ID del estado operativo (7=Verde, 6=Azul, 4=Offline)
  /// [isMap] - Si es true, usa carpeta "Arriba" (para mapa), si es false usa "Lateral" (para lista)
  /// Retorna la ruta completa del asset o null si no se encuentra
  static String? getIconPathByState(String? iconName, int? idEstadoOperativo, {bool isMap = false}) {
    // Si es 'default' o null, usar "Default.png" de la carpeta correspondiente
    if (iconName == null || iconName == 'default' || iconName.isEmpty) {
      // Obtener carpeta de color según estado
      final colorFolder = _getColorFolderByState(idEstadoOperativo, isMap: isMap);
      // Construir ruta para Default.png
      final defaultPath = '$colorFolder/Default.png';
      debugPrint('🎨 Icono: Default, Estado: $idEstadoOperativo, Tipo: ${isMap ? "Arriba" : "Lateral"} -> $defaultPath');
      return defaultPath;
    }
    
    // Extraer nombre base (por si viene con ruta completa)
    final baseName = extractIconBaseName(iconName);
    
    // Obtener carpeta de color según estado
    final colorFolder = _getColorFolderByState(idEstadoOperativo, isMap: isMap);
    
    // Construir ruta completa
    final iconPath = '$colorFolder/$baseName.png';
    
    debugPrint('🎨 Icono: $baseName, Estado: $idEstadoOperativo, Tipo: ${isMap ? "Arriba" : "Lateral"} -> $iconPath');
    
    return iconPath;
  }

  /// Obtiene la ruta del asset PNG según el nombre del icono (método legacy - para compatibilidad)
  /// Usa la carpeta Gris como fallback
  static String? getAssetPathByName(String iconName) {
    try {
      final iconMap = availableIcons.firstWhere(
        (icon) => icon['name'] == iconName,
        orElse: () => {'name': 'default', 'assetPath': null},
      );
      return iconMap['assetPath'] as String?;
    } catch (e) {
      debugPrint('❌ Error al obtener assetPath para $iconName: $e');
      return null;
    }
  }
  
  /// Método legacy para compatibilidad (retorna null ya que ahora usamos PNG)
  @Deprecated('Usar getAssetPathByName en su lugar')
  static IconData? getIconDataByName(String iconName) {
    return null;
  }

  /// Guarda el icono personalizado para un dispositivo
  /// 
  /// [iconName] - Puede ser nombre base (ej: 'Carro') o ruta completa (ej: 'assets/Iconos/Lateral/Gris/Carro.png')
  /// Se extraerá automáticamente el nombre base para guardarlo
  Future<void> saveIconPreference(int deviceId, String iconName) async {
    try {
      // Extraer nombre base del icono (sin ruta ni extensión)
      final baseName = extractIconBaseName(iconName);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$deviceId', baseName);
      debugPrint('✅ Icono guardado: Dispositivo $deviceId -> $baseName (desde: $iconName)');
      
      // Notificar cambio para actualizar lista de dispositivos
      iconChangedNotifier.value = deviceId;
    } catch (e) {
      debugPrint('❌ Error al guardar icono: $e');
    }
  }

  /// Obtiene el icono personalizado de un dispositivo
  /// Retorna null si no hay icono personalizado (usa el por defecto)
  Future<String?> getIconPreference(int deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iconName = prefs.getString('$_prefix$deviceId');
      return iconName;
    } catch (e) {
      debugPrint('❌ Error al obtener icono: $e');
      return null;
    }
  }

  /// Elimina el icono personalizado de un dispositivo (vuelve al por defecto)
  Future<void> removeIconPreference(int deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$deviceId');
      debugPrint('✅ Icono eliminado: Dispositivo $deviceId');
    } catch (e) {
      debugPrint('❌ Error al eliminar icono: $e');
    }
  }

  /// Obtiene todos los iconos personalizados
  Future<Map<int, String>> getAllIconPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
      
      final Map<int, String> preferences = {};
      for (final key in keys) {
        final deviceIdStr = key.replaceFirst(_prefix, '');
        final deviceId = int.tryParse(deviceIdStr);
        if (deviceId != null) {
          final iconName = prefs.getString(key);
          if (iconName != null) {
            preferences[deviceId] = iconName;
          }
        }
      }
      
      return preferences;
    } catch (e) {
      debugPrint('❌ Error al obtener todos los iconos: $e');
      return {};
    }
  }
}
