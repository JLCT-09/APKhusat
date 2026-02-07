import 'package:share_plus/share_plus.dart';

/// Servicio para compartir ubicación de vehículos.
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Comparte la ubicación de un vehículo.
  /// 
  /// Genera un mensaje con:
  /// - Placa del vehículo
  /// - Link de Google Maps con las coordenadas
  /// 
  /// Permite compartir por WhatsApp, SMS, Email, etc.
  Future<void> shareLocation({
    required String placa,
    required double latitude,
    required double longitude,
  }) async {
    final googleMapsUrl = 'https://www.google.com/maps?q=$latitude,$longitude';
    final message = '📍 Ubicación en tiempo real del vehículo $placa: $googleMapsUrl';

    await Share.share(
      message,
      subject: 'Ubicación del vehículo $placa',
    );
  }
}
