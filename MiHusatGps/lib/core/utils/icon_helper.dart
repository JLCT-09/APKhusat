import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Helper para cargar y convertir iconos vectoriales (FontAwesome) a BitmapDescriptor
/// 
/// Soluciona el problema de transparencia asegurando que el icono
/// esté completamente renderizado antes de crear el BitmapDescriptor
class IconHelper {
  // Caché de iconos PNG con LRU (Least Recently Used)
  // Key: 'assetPath_size_rotation', Value: BitmapDescriptor
  static final Map<String, BitmapDescriptor> _iconCache = {};
  static const int _maxCacheSize = 150; // Límite de entradas en caché
  
  /// Limpia el caché de iconos (útil para liberar memoria)
  static void clearIconCache() {
    _iconCache.clear();
    debugPrint('🗑️ Caché de iconos limpiado');
  }
  
  /// Obtiene el tamaño actual del caché
  static int get cacheSize => _iconCache.length;
  /// Convierte grados a radianes
  /// 
  /// [degrees] - Ángulo en grados (0-360)
  /// Retorna el ángulo en radianes
  static double degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }

  /// Determina el color del icono según el estado operativo del dispositivo
  /// 
  /// Prioridad: idEstadoOperativo > codigoEstadoOperativo > movimiento/velocidad
  /// 
  /// [idEstadoOperativo] - ID del estado operativo (7=Verde, 6=Azul, 4=Plomo)
  /// [codigoEstadoOperativo] - Código del estado operativo del backend
  /// [movimiento] - Campo movimiento del dispositivo (fallback)
  /// [velocidad] - Velocidad del dispositivo (fallback si movimiento es null)
  /// Retorna el Color correspondiente al estado
  static Color getColorFromEstado({
    int? idEstadoOperativo,
    String? codigoEstadoOperativo,
    bool? movimiento,
    double? velocidad,
  }) {
    // PRIORIDAD 1: idEstadoOperativo (más confiable)
    if (idEstadoOperativo != null) {
      switch (idEstadoOperativo) {
        case 7: // EN MOVIMIENTO
          return Colors.green;
        case 6: // ESTÁTICO
          return Colors.blue;
        case 4: // FUERA DE LÍNEA
          return Colors.grey;
        default:
          // Si es otro ID, usar lógica de fallback
          break;
      }
    }
    
    // PRIORIDAD 2: codigoEstadoOperativo
    if (codigoEstadoOperativo != null && codigoEstadoOperativo.isNotEmpty) {
      if (codigoEstadoOperativo == 'OPER_EN_MOVIMIENTO') {
        return Colors.green;
      } else if (codigoEstadoOperativo == 'OPER_ESTATICO') {
        return Colors.blue;
      } else if (codigoEstadoOperativo == 'OPER_FUERA_DE_LINEA') {
        return Colors.grey;
      }
    }
    
    // PRIORIDAD 3: FALLBACK - usar movimiento o velocidad
    if (movimiento != null) {
      return movimiento ? Colors.green : Colors.blue;
    }
    
    // PRIORIDAD 4: FALLBACK - usar velocidad
    if (velocidad != null) {
      return velocidad > 0 ? Colors.green : Colors.blue;
    }
    
    // Último fallback: Azul (Estático)
    return Colors.blue;
  }

  /// Determina la ruta del asset PNG según el estado operativo del dispositivo
  /// 
  /// Prioridad: idEstadoOperativo > codigoEstadoOperativo > movimiento/velocidad
  /// 
  /// [idEstadoOperativo] - ID del estado operativo (7=Verde, 6=Azul, 4=Plomo)
  /// [codigoEstadoOperativo] - Código del estado operativo del backend
  /// [movimiento] - Campo movimiento del dispositivo (fallback)
  /// [velocidad] - Velocidad del dispositivo (fallback si movimiento es null)
  /// Retorna la ruta del asset PNG
  static String getAssetPathFromEstado({
    int? idEstadoOperativo,
    String? codigoEstadoOperativo,
    bool? movimiento,
    double? velocidad,
  }) {
    // PRIORIDAD 1: idEstadoOperativo (más confiable)
    if (idEstadoOperativo != null) {
      switch (idEstadoOperativo) {
        case 7: // EN MOVIMIENTO
          return 'assets/images/carro_verde.png';
        case 6: // ESTÁTICO
          return 'assets/images/carro_azul.png';
        case 4: // FUERA DE LÍNEA
          return 'assets/images/carro_plomo.png';
        default:
          // Si es otro ID, usar lógica de fallback
          break;
      }
    }
    
    // PRIORIDAD 2: codigoEstadoOperativo
    if (codigoEstadoOperativo != null && codigoEstadoOperativo.isNotEmpty) {
      if (codigoEstadoOperativo == 'OPER_EN_MOVIMIENTO') {
        return 'assets/images/carro_verde.png';
      } else if (codigoEstadoOperativo == 'OPER_ESTATICO') {
        return 'assets/images/carro_azul.png';
      } else if (codigoEstadoOperativo == 'OPER_FUERA_DE_LINEA') {
        return 'assets/images/carro_plomo.png';
      }
    }
    
    // PRIORIDAD 3: FALLBACK - usar movimiento
    if (movimiento != null) {
      return movimiento ? 'assets/images/carro_verde.png' : 'assets/images/carro_azul.png';
    }
    
    // PRIORIDAD 4: FALLBACK - usar velocidad
    if (velocidad != null) {
      return velocidad > 0 ? 'assets/images/carro_verde.png' : 'assets/images/carro_azul.png';
    }
    
    // Último fallback: Azul (Estático)
    return 'assets/images/carro_azul.png';
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
  static String? getIconForState(int? stateId) {
    if (stateId == null) return null;
    
    switch (stateId) {
      case 7: // EN MOVIMIENTO
        return 'assets/images/carro_verde.png';
      case 6: // ESTÁTICO
        return 'assets/images/carro_azul.png';
      case 4: // FUERA DE LÍNEA
        return 'assets/images/carro_plomo.png';
      default:
        return null;
    }
  }
  /// Convierte un IconData (FontAwesome) a BitmapDescriptor
  /// 
  /// [iconData] - IconData del icono de FontAwesome (ej: FontAwesomeIcons.car)
  /// [color] - Color del icono (Verde para movimiento, Azul para estático)
  /// [size] - Tamaño del icono en píxeles (por defecto 80)
  /// [rotation] - Rotación del icono en grados (0-360, opcional, para mostrar dirección)
  /// 
  /// Retorna un BitmapDescriptor listo para usar en GoogleMap
  static Future<BitmapDescriptor> iconDataToBitmapDescriptor(
    IconData iconData,
    Color color, {
    int? size, // Si es null, se calcula según devicePixelRatio
    double? rotation,
    double? devicePixelRatio,
  }) async {
    try {
      // Calcular tamaño si no se proporciona
      final int finalSize = size ?? calculateIconSize(devicePixelRatio ?? 3.0);
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Usar el tamaño calculado
      final canvasSize = finalSize;
      final iconSize = Size(canvasSize.toDouble(), canvasSize.toDouble());
      
      // Diseño de "Pin" o "Burbuja" notorio con sombra
      // Sombra para efecto de profundidad
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(iconSize.width / 2 + 2, iconSize.height / 2 + 2),
        iconSize.width / 2,
        shadowPaint,
      );
      
      // Círculo de fondo con el color del estado (más grande y notorio)
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(iconSize.width / 2, iconSize.height / 2),
        iconSize.width / 2,
        circlePaint,
      );
      
      // Borde blanco más grueso para mejor visibilidad
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4; // Borde más grueso para notoriedad
      canvas.drawCircle(
        Offset(iconSize.width / 2, iconSize.height / 2),
        iconSize.width / 2 - 2,
        borderPaint,
      );
      
      // Dibujar el icono de FontAwesome en el centro
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            fontSize: finalSize * 0.6, // 60% del tamaño total (más grande para notoriedad)
            color: Colors.white,
            fontWeight: FontWeight.w700, // Más grueso para mejor visibilidad
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      textPainter.layout();
      
      // Aplicar rotación si se proporciona
      if (rotation != null) {
        canvas.save();
        // Rotar alrededor del centro del icono
        canvas.translate(iconSize.width / 2, iconSize.height / 2);
        canvas.rotate(degreesToRadians(rotation));
        canvas.translate(-iconSize.width / 2, -iconSize.height / 2);
      }
      
      // Centrar el icono
      final offset = Offset(
        (iconSize.width - textPainter.width) / 2,
        (iconSize.height - textPainter.height) / 2,
      );
      
      textPainter.paint(canvas, offset);
      
      // Restaurar canvas si se aplicó rotación
      if (rotation != null) {
        canvas.restore();
      }
      
      // Convertir a imagen con alta resolución para evitar pixelación
      final picture = recorder.endRecording();
      // Usar tamaño alto para mantener calidad al escalar (mínimo 150x150)
      // canvasSize ya está declarado en la línea 32
      final image = await picture.toImage(canvasSize, canvasSize);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('No se pudo convertir el icono a bytes');
      }
      
      final uint8List = byteData.buffer.asUint8List();
      
      // Liberar recursos
      image.dispose();
      
      debugPrint('✅ Icono vectorial convertido: ${iconData.codePoint}');
      return BitmapDescriptor.fromBytes(uint8List);
    } catch (e) {
      debugPrint('❌ Error al convertir icono vectorial: $e');
      // Retornar un icono por defecto si falla
      return createDefaultIcon();
    }
  }
  /// Convierte un asset de imagen a BitmapDescriptor
  /// 
  /// [assetPath] - Ruta del asset (ej: 'assets/icons/auto.png')
  /// [width] - Ancho deseado del icono (por defecto 80)
  /// 
  /// Retorna un BitmapDescriptor listo para usar en GoogleMap
  static Future<BitmapDescriptor> getBytesFromAsset(
    String assetPath,
    int width,
  ) async {
    try {
      // Cargar el asset como ByteData
      final ByteData data = await rootBundle.load(assetPath);
      
      // Decodificar la imagen
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      
      // Obtener el frame de la imagen
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      // Convertir a ByteData en formato PNG
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData == null) {
        throw Exception('No se pudo convertir la imagen a bytes');
      }
      
      // Crear BitmapDescriptor desde bytes
      final Uint8List uint8List = byteData.buffer.asUint8List();
      final BitmapDescriptor bitmapDescriptor = BitmapDescriptor.fromBytes(uint8List);
      
      // Liberar recursos de la imagen
      image.dispose();
      
      debugPrint('✅ Icono cargado desde asset: $assetPath');
      return bitmapDescriptor;
    } catch (e) {
      debugPrint('❌ Error al cargar icono desde asset $assetPath: $e');
      // Retornar un icono por defecto si falla
      return createDefaultIcon();
    }
  }

  /// Calcula el tamaño del icono basado en la densidad de pantalla del dispositivo
  /// 
  /// Usa un tamaño base de 45dp y lo escala según devicePixelRatio
  /// Limita el tamaño máximo para evitar iconos demasiado grandes
  /// 
  /// [devicePixelRatio] - Densidad de pantalla del dispositivo (obtenido de MediaQuery)
  /// Retorna el tamaño en píxeles para el icono
  static int calculateIconSize(double devicePixelRatio) {
    // Tamaño base en dp (density-independent pixels)
    const double baseSizeDp = 45.0;
    
    // Calcular tamaño en píxeles según densidad
    double calculatedSize = baseSizeDp * devicePixelRatio;
    
    // Limitar el tamaño máximo para evitar iconos demasiado grandes
    // Máximo: 120px (equivalente a ~40dp en pantalla 3x)
    // Mínimo: 40px (equivalente a ~40dp en pantalla 1x)
    if (calculatedSize > 120) {
      calculatedSize = 120;
    } else if (calculatedSize < 40) {
      calculatedSize = 40;
    }
    
    return calculatedSize.round();
  }

  /// Carga un PNG desde assets con configuración de pantalla para mantener resolución
  /// 
  /// OPTIMIZACIÓN: Implementa caché LRU para evitar cargar el mismo icono múltiples veces
  /// 
  /// [assetPath] - Ruta del asset PNG (ej: 'assets/images/carro_verde.png')
  /// [size] - Tamaño deseado del icono (por defecto se calcula según densidad de pantalla)
  /// [rotation] - Rotación del icono en grados (0-360, opcional)
  /// [devicePixelRatio] - Densidad de pantalla (opcional, si no se proporciona usa 3.0)
  /// 
  /// Retorna un BitmapDescriptor escalado y optimizado para GoogleMap
  static Future<BitmapDescriptor> loadPngFromAsset(
    String assetPath, {
    int? size, // Si es null, se calcula según devicePixelRatio
    double? rotation,
    double? devicePixelRatio,
  }) async {
    // Calcular tamaño si no se proporciona
    final int finalSize = size ?? calculateIconSize(devicePixelRatio ?? 3.0);
    
    // Crear clave única para el caché (incluye rotación para diferentes ángulos)
    final rotationKey = rotation != null ? rotation.round() : 0;
    final cacheKey = '${assetPath}_${finalSize}_${rotationKey}';
    
    // OPTIMIZACIÓN: Verificar caché primero
    if (_iconCache.containsKey(cacheKey)) {
      debugPrint('⚡ Icono desde caché: $cacheKey');
      return _iconCache[cacheKey]!;
    }
    
    try {
      // Cargar el PNG como ByteData
      final ByteData data = await rootBundle.load(assetPath);
      
      // PRIMERO: Decodificar sin escalado para obtener dimensiones originales
      final ui.Codec originalCodec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo originalFrame = await originalCodec.getNextFrame();
      final ui.Image tempImage = originalFrame.image;
      final int originalWidth = tempImage.width;
      final int originalHeight = tempImage.height;
      tempImage.dispose();
      
      // Calcular proporción de aspecto
      final double aspectRatio = originalWidth / originalHeight;
      int targetWidth = finalSize;
      int targetHeight = finalSize;
      
      // Mantener proporción: ajustar solo el ancho o alto según corresponda
      if (aspectRatio > 1.0) {
        // Imagen más ancha que alta
        targetHeight = (finalSize / aspectRatio).round();
      } else if (aspectRatio < 1.0) {
        // Imagen más alta que ancha
        targetWidth = (finalSize * aspectRatio).round();
      }
      // Si aspectRatio == 1.0, ya es cuadrado, usar finalSize para ambos
      
      // Decodificar la imagen con el tamaño calculado manteniendo proporción
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      
      // Obtener el frame de la imagen
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;
      
      // Si hay rotación, aplicar transformación
      if (rotation != null && rotation != 0) {
        // Crear canvas para rotar la imagen (usar tamaño cuadrado para el canvas final)
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final canvasSize = finalSize.toDouble();
        final iconSize = Size(canvasSize, canvasSize);
        
        // Calcular offset para centrar la imagen en el canvas cuadrado
        final offsetX = (canvasSize - targetWidth) / 2;
        final offsetY = (canvasSize - targetHeight) / 2;
        
        // Aplicar rotación alrededor del centro del canvas
        canvas.save();
        canvas.translate(iconSize.width / 2, iconSize.height / 2);
        canvas.rotate(degreesToRadians(rotation));
        canvas.translate(-iconSize.width / 2, -iconSize.height / 2);
        
        // Dibujar la imagen rotada centrada
        canvas.drawImage(originalImage, Offset(offsetX, offsetY), Paint());
        canvas.restore();
        
        // Convertir a imagen (siempre cuadrado para el marcador)
        final picture = recorder.endRecording();
        final rotatedImage = await picture.toImage(finalSize, finalSize);
        originalImage.dispose();
        
        // Convertir a ByteData
        final byteData = await rotatedImage.toByteData(format: ui.ImageByteFormat.png);
        rotatedImage.dispose();
        
        if (byteData == null) {
          throw Exception('No se pudo convertir la imagen rotada a bytes');
        }
        
        final uint8List = byteData.buffer.asUint8List();
        final bitmapDescriptor = BitmapDescriptor.fromBytes(uint8List);
        
        // OPTIMIZACIÓN: Guardar en caché antes de retornar
        _addToCache(cacheKey, bitmapDescriptor);
        
        debugPrint('✅ PNG cargado y rotado desde asset: $assetPath (tamaño: ${finalSize}x$finalSize, rotación: ${rotation}°)');
        return bitmapDescriptor;
      } else {
        // Sin rotación: crear canvas cuadrado y centrar la imagen manteniendo proporción
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final canvasSize = finalSize.toDouble();
        
        // Calcular offset para centrar la imagen en el canvas cuadrado
        final offsetX = (canvasSize - targetWidth) / 2;
        final offsetY = (canvasSize - targetHeight) / 2;
        
        // Dibujar la imagen centrada en el canvas cuadrado
        canvas.drawImage(originalImage, Offset(offsetX, offsetY), Paint());
        
        // Convertir a imagen (siempre cuadrado para el marcador)
        final picture = recorder.endRecording();
        final finalImage = await picture.toImage(finalSize, finalSize);
        originalImage.dispose();
        
        // Convertir a ByteData
        final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
        finalImage.dispose();
        
        if (byteData == null) {
          throw Exception('No se pudo convertir la imagen a bytes');
        }
        
        final uint8List = byteData.buffer.asUint8List();
        final bitmapDescriptor = BitmapDescriptor.fromBytes(uint8List);
        
        // OPTIMIZACIÓN: Guardar en caché antes de retornar
        _addToCache(cacheKey, bitmapDescriptor);
        
        debugPrint('✅ PNG cargado desde asset: $assetPath (tamaño original: ${originalWidth}x$originalHeight, escalado: ${targetWidth}x$targetHeight, canvas: ${finalSize}x$finalSize)');
        return bitmapDescriptor;
      }
    } catch (e) {
      debugPrint('❌ Error al cargar PNG desde asset $assetPath: $e');
      // FALLBACK: Retornar un icono de color sólido si el PNG no existe
      return createFallbackIcon(finalSize, rotation);
    }
  }

  /// Crea un icono de fallback (marcador de color sólido) si el PNG no se encuentra
  /// 
  /// [size] - Tamaño del icono
  /// [rotation] - Rotación opcional
  /// 
  /// Retorna un BitmapDescriptor con un círculo de color sólido
  static Future<BitmapDescriptor> createFallbackIcon(
    int size, [
    double? rotation,
  ]) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final iconSize = Size(size.toDouble(), size.toDouble());
      
      // Aplicar rotación si se proporciona
      if (rotation != null) {
        canvas.save();
        canvas.translate(iconSize.width / 2, iconSize.height / 2);
        canvas.rotate(degreesToRadians(rotation));
        canvas.translate(-iconSize.width / 2, -iconSize.height / 2);
      }
      
      // Sombra
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(iconSize.width / 2 + 2, iconSize.height / 2 + 2),
        iconSize.width / 2,
        shadowPaint,
      );
      
      // Círculo de color sólido (gris como fallback)
      final circlePaint = Paint()
        ..color = Colors.grey
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
      
      // Restaurar canvas si se aplicó rotación
      if (rotation != null) {
        canvas.restore();
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('No se pudo convertir el fallback a bytes');
      }
      
      final uint8List = byteData.buffer.asUint8List();
      image.dispose();
      
      debugPrint('✅ Icono de fallback creado (tamaño: ${size}x$size)');
      return BitmapDescriptor.fromBytes(uint8List);
    } catch (e) {
      debugPrint('❌ Error al crear icono de fallback: $e');
      // Último recurso: icono por defecto
      return createDefaultIcon();
    }
  }

  /// Agrega un icono al caché con política LRU (elimina el más antiguo si excede el límite)
  static void _addToCache(String key, BitmapDescriptor descriptor) {
    // Si el caché está lleno, eliminar la entrada más antigua (primera en el Map)
    if (_iconCache.length >= _maxCacheSize && !_iconCache.containsKey(key)) {
      final firstKey = _iconCache.keys.first;
      _iconCache.remove(firstKey);
      debugPrint('🗑️ Entrada eliminada del caché (LRU): $firstKey');
    }
    
    _iconCache[key] = descriptor;
    
    // Mover la entrada al final (más reciente) si ya existía
    if (_iconCache.length > 1 && _iconCache.containsKey(key)) {
      final value = _iconCache.remove(key);
      if (value != null) {
        _iconCache[key] = value;
      }
    }
  }
  
  /// Crea un icono por defecto (auto rojo corporativo) si falla la carga del asset
  static Future<BitmapDescriptor> createDefaultIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 80);
    
    // Fondo blanco sólido para evitar transparencia
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      backgroundPaint,
    );
    
    // Auto rojo corporativo
    final carPaint = Paint()
      ..color = const Color(0xFFEF1A2D)
      ..style = PaintingStyle.fill;
    
    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.35, size.width * 0.7, size.height * 0.35),
      const Radius.circular(6),
    );
    canvas.drawRRect(carBody, carPaint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }
}
