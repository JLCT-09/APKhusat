import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../domain/models/device_model.dart';

/// Widget que muestra el AppBar personalizado para el modo Historial
/// Muestra la placa y el IMEI del dispositivo seleccionado
class MapCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DeviceModel? device;
  final VoidCallback onBackPressed;

  const MapCustomAppBar({
    super.key,
    required this.device,
    required this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (device == null) {
      return AppBar(
        title: const Text('Historial'),
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          // Glassmorphism: fondo negro con opacidad y blur
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
      ),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed,
        tooltip: 'Regresar al Monitor',
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Placa en negrita (grande)
          Text(
            device!.placa != null && device!.placa!.isNotEmpty
                ? device!.placa!
                : device!.nombre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // IMEI en tamaño pequeño
          if (device!.imei != null && device!.imei!.isNotEmpty)
            Text(
              device!.imei!,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white70,
              ),
            ),
        ],
      ),
      centerTitle: true,
    );
  }
}
