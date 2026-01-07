import 'package:flutter/material.dart';

/// Widget flotante para centrar la cámara del mapa en la ubicación actual del usuario.
/// 
/// Botón blanco con icono rojo (identidad HusatGps) que al presionarlo
/// anima la cámara hacia la posición actual del usuario con zoom 16.
class CenterLocationFab extends StatelessWidget {
  /// Callback que se ejecuta al presionar el botón
  final VoidCallback onPressed;

  const CenterLocationFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.white,
      elevation: 4,
      heroTag: 'center_location',
      child: const Icon(
        Icons.my_location,
        color: Colors.red,
      ),
    );
  }
}
