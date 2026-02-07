import 'package:flutter/material.dart';

/// Widget flotante para activar/desactivar la capa de tráfico en el mapa.
/// 
/// Muestra un botón con icono de semáforo que cambia de color según el estado:
/// - Rojo cuando está activado
/// - Blanco cuando está desactivado
class TrafficFab extends StatelessWidget {
  /// Indica si la capa de tráfico está activada
  final bool trafficEnabled;
  
  /// Callback que se ejecuta al presionar el botón
  final VoidCallback onPressed;

  const TrafficFab({
    super.key,
    required this.trafficEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: trafficEnabled ? Colors.red : Colors.white,
      elevation: 4,
      heroTag: 'traffic_toggle',
      child: Icon(
        Icons.traffic,
        color: trafficEnabled ? Colors.white : Colors.grey,
      ),
    );
  }
}
