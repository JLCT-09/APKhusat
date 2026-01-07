import 'dart:ui';
import 'package:flutter/material.dart';

/// Barra de acciones con efecto glassmorphism.
/// 
/// Muestra botones de acción con efecto de cristal:
/// - Detalle, Seguimiento, Historial, Comando, Compartir, Ver más
class GlassActionBar extends StatelessWidget {
  final VoidCallback onDetalle;
  final VoidCallback onSeguimiento;
  final VoidCallback onHistorial;
  final VoidCallback onComando;
  final VoidCallback onCompartir;
  final VoidCallback onVerMas;

  const GlassActionBar({
    super.key,
    required this.onDetalle,
    required this.onSeguimiento,
    required this.onHistorial,
    required this.onComando,
    required this.onCompartir,
    required this.onVerMas,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.info_outline,
                  label: 'Detalle',
                  onTap: onDetalle,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.my_location,
                  label: 'Seguimiento',
                  onTap: onSeguimiento,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history,
                  label: 'Historial',
                  onTap: onHistorial,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.settings_remote,
                  label: 'Comando',
                  onTap: onComando,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: 'Compartir',
                  onTap: onCompartir,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.more_horiz,
                  label: 'Ver más',
                  onTap: onVerMas,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
