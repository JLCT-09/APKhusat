import 'package:url_launcher/url_launcher.dart';

/// Utilidad para abrir aplicaciones de navegación externas (Waze, Google Maps)
class NavigationLauncher {
  /// Abre la ubicación en la app de navegación preferida del usuario
  /// 
  /// [latitude] - Latitud del destino
  /// [longitude] - Longitud del destino
  /// 
  /// Retorna true si se pudo abrir alguna app, false en caso contrario
  static Future<bool> openNavigationApp({
    required double latitude,
    required double longitude,
  }) async {
    // Intentar primero con Waze (más popular en algunos países)
    final wazeUrl = 'waze://?ll=$latitude,$longitude&navigate=yes';
    if (await canLaunchUrl(Uri.parse(wazeUrl))) {
      try {
        await launchUrl(Uri.parse(wazeUrl), mode: LaunchMode.externalApplication);
        return true;
      } catch (e) {
        // Si falla Waze, intentar con Google Maps
      }
    }

    // Si Waze no está disponible, usar Google Maps
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // Si Google Maps también falla, intentar con el esquema nativo
    }

    // Último recurso: usar el esquema nativo de Google Maps
    final nativeMapsUrl = 'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving';
    try {
      if (await canLaunchUrl(Uri.parse(nativeMapsUrl))) {
        await launchUrl(Uri.parse(nativeMapsUrl), mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // Si todo falla, retornar false
    }

    return false;
  }

  /// Abre Waze específicamente
  static Future<bool> openWaze({
    required double latitude,
    required double longitude,
  }) async {
    final url = 'waze://?ll=$latitude,$longitude&navigate=yes';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // Waze no está instalado o no se pudo abrir
    }
    return false;
  }

  /// Abre Google Maps específicamente
  static Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
  }) async {
    // Intentar primero con el esquema nativo
    final nativeUrl = 'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving';
    try {
      if (await canLaunchUrl(Uri.parse(nativeUrl))) {
        await launchUrl(Uri.parse(nativeUrl), mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // Si el esquema nativo no funciona, usar la URL web
    }

    // Usar URL web como fallback
    final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    try {
      if (await canLaunchUrl(Uri.parse(webUrl))) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // No se pudo abrir
    }
    return false;
  }
}
