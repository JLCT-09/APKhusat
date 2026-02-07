import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/icon_preference_service.dart';

/// Widget que representa un ítem de dispositivo en la lista
/// Muestra información del dispositivo con color sincronizado basado en movimiento
class DeviceListItem extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;

  const DeviceListItem({
    super.key,
    required this.device,
    this.onTap,
  });

  /// Formatea el tiempo relativo desde ultimaActualizacion
  String _formatTimeAgo(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'min'}';
    } else {
      return 'Ahora';
    }
  }

  /// Determina el color y texto del estado basado en idEstadoOperativo
  /// 
  /// Fuente de verdad: device.idEstadoOperativo
  /// - 7 (En Movimiento): Verde, "En Movimiento"
  /// - 6 (Estático): Azul, "Estático"
  /// - 4 (Fuera de Línea): Gris, "Fuera de Línea"
  /// - Default: Gris, "Desconocido"
  Map<String, dynamic> _getEstadoFromIdOperativo() {
    final idEstado = device.idEstadoOperativo;
    
    switch (idEstado) {
      case 7: // EN MOVIMIENTO
        return {
          'color': const Color(0xFF4CAF50), // Verde
          'texto': 'En Movimiento',
        };
      case 6: // ESTÁTICO
        return {
          'color': const Color(0xFF2196F3), // Azul
          'texto': 'Estático',
        };
      case 4: // FUERA DE LÍNEA
        return {
          'color': Colors.grey, // Plomo
          'texto': 'Fuera de Línea',
        };
      default:
        return {
          'color': Colors.grey, // Plomo
          'texto': 'Desconocido',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // LÓGICA: Usar idEstadoOperativo como fuente de verdad
    final estadoInfo = _getEstadoFromIdOperativo();
    final Color estadoColor = estadoInfo['color'] as Color;
    final String textoEstado = estadoInfo['texto'] as String;
    
    final tiempoRelativo = _formatTimeAgo(device.lastUpdate);
    
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0), // Aumentado de 10.0 a 14.0
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Extremo Izquierdo: Icono de vehículo y tiempo relativo
                Column(
                  children: [
                    FutureBuilder<String?>(
                      future: IconPreferenceService().getIconPreference(device.idDispositivo),
                      builder: (context, snapshot) {
                        final iconName = snapshot.data ?? 'default';
                        
                        // Obtener ruta del icono según estado operativo (Lateral para lista)
                        // Si iconName es 'default', getIconPathByState retornará la ruta a Default.png
                        final assetPath = IconPreferenceService.getIconPathByState(
                          iconName,
                          device.idEstadoOperativo,
                          isMap: false, // false = Lateral (para lista)
                        );
                        
                        // Usar PNG desde assets según estado (puede ser Default.png o icono personalizado)
                        if (assetPath != null) {
                          return Image.asset(
                            assetPath,
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ Error al cargar icono: $assetPath');
                              // Fallback: intentar con Default.png en carpeta Gris
                              final fallbackPath = IconPreferenceService.getIconPathByState(
                                'default',
                                null, // null = Gris
                                isMap: false,
                              );
                              if (fallbackPath != null) {
                                return Image.asset(
                                  fallbackPath,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Último fallback: icono por defecto con color blend
                                    return Image.asset(
                                      'assets/images/carro_verde.png',
                                      width: 32,
                                      height: 32,
                                      color: estadoColor,
                                      colorBlendMode: BlendMode.srcIn,
                                    );
                                  },
                                );
                              }
                              // Fallback si Default.png no se encuentra
                              return Image.asset(
                                'assets/images/carro_verde.png',
                                width: 32,
                                height: 32,
                                color: estadoColor,
                                colorBlendMode: BlendMode.srcIn,
                              );
                            },
                          );
                        } else {
                          // Fallback: icono por defecto con color blend (si getIconPathByState retorna null)
                          return Image.asset(
                            'assets/images/carro_verde.png',
                            width: 32,
                            height: 32,
                            color: estadoColor,
                            colorBlendMode: BlendMode.srcIn,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tiempoRelativo,
                      style: TextStyle(
                        fontSize: 11, // Aumentado de 10 a 11
                        color: estadoColor, // Color según idEstadoOperativo
                        fontWeight: FontWeight.w600, // Aumentado de w500 a w600
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Cuerpo Central: Información del dispositivo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Línea 1: nombre (o placa si existe) + modeloGps en Negrita (tamaño reducido)
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15, // Aumentado de 14 a 15
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: device.placa != null && device.placa!.isNotEmpty
                                  ? device.placa!
                                  : device.nombre,
                            ),
                            if (device.modeloGps != null && device.modeloGps!.isNotEmpty)
                              TextSpan(
                                text: ' ${device.modeloGps}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      
                      // Línea 2: "IMEI: " + imei (tamaño reducido)
                      Text(
                        'IMEI: ${device.imei ?? "---"}',
                        style: TextStyle(
                          fontSize: 12, // Aumentado de 11 a 12
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4), // Aumentado de 3 a 4
                      
                      // Línea 3: Energía Ext y Bat. GPS
                      Text(
                        'Energía Ext: ${device.energiaExterna?.toStringAsFixed(2) ?? '0.00'}V | Bat. GPS: ${device.bateria ?? 0}%',
                        style: TextStyle(
                          fontSize: 11, // Aumentado de 9 a 11
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4), // Aumentado de 3 a 4
                      
                      // Línea 4: Velocidad y Rumbo
                      Text(
                        'Velocidad: ${(device.velocidad ?? 0.0).toStringAsFixed(1)} km/h | Rumbo: ${device.rumbo != null ? device.rumbo!.toStringAsFixed(0) : '--'}°',
                        style: TextStyle(
                          fontSize: 11, // Aumentado de 9 a 11
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Extremo Derecho: Texto de estado basado en idEstadoOperativo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Aumentado padding
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1), // Fondo con color según idEstadoOperativo
                    borderRadius: BorderRadius.circular(6), // Aumentado de 4 a 6
                  ),
                  child: Text(
                    textoEstado, // "En Movimiento", "Estático", "Fuera de Línea", "Desconocido"
                    style: TextStyle(
                      fontSize: 10, // Aumentado de 9 a 10
                      color: estadoColor, // Texto con color según idEstadoOperativo
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider inferior de lado a lado (sutil)
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}
