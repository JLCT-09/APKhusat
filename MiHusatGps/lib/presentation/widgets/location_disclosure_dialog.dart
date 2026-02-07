import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo de Divulgación Prominente (Prominent Disclosure) requerido por Google Play
/// para solicitar el permiso ACCESS_BACKGROUND_LOCATION.
/// 
/// Este diálogo debe mostrarse ANTES de solicitar el permiso de ubicación en segundo plano.
/// Cumple con las políticas de Google Play sobre divulgación prominente.
class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.location_on,
            color: const Color(0xFFEF1A2D), // Rojo corporativo
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Uso de ubicación en segundo plano',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Husat365 recopila datos de ubicación para habilitar el monitoreo y rastreo de su ruta en tiempo real incluso cuando la aplicación está cerrada o no está en uso.',
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
        ),
      ),
      actions: [
        // Botón Rechazar - Cierra la aplicación
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            // Cerrar la aplicación de forma limpia usando SystemNavigator
            Future.delayed(const Duration(milliseconds: 200), () {
              SystemNavigator.pop();
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
          ),
          child: const Text(
            'Rechazar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Botón Aceptar - Cierra el diálogo y retorna true
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF1A2D), // Rojo corporativo
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Aceptar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

}
