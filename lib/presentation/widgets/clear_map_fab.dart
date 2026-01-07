import 'package:flutter/material.dart';

/// Widget flotante para limpiar todos los marcadores y el rastro del mapa.
/// 
/// Botón blanco con icono rojo (identidad HusatGps) que elimina:
/// - Todos los marcadores de vehículos (carros rojos)
/// - Todos los puntos del rastro (polyline)
/// 
/// Útil para evitar saturación visual cuando hay muchos vehículos en el mapa.
class ClearMapFab extends StatelessWidget {
  /// Callback que se ejecuta al presionar el botón
  final VoidCallback onPressed;

  const ClearMapFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.white,
      elevation: 4,
      heroTag: 'clear_markers',
      child: const Icon(
        Icons.delete_sweep,
        color: Colors.red,
      ),
    );
  }
}
