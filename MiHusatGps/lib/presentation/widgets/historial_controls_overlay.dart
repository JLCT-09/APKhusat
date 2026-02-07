import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

/// Widget que muestra los controles de reproducción del historial
/// Recibe callbacks para comunicarse con el MapScreenState
class HistorialControlsOverlay extends StatelessWidget {
  final double playbackSliderValue;
  final double playbackSpeed;
  final bool isPlaying;
  final int playbackHistoryLength;
  final Function(double) onSliderChanged;
  final VoidCallback onSliderStart;
  final VoidCallback onPlayPausePressed;
  final Function(double) onSpeedChanged;

  const HistorialControlsOverlay({
    super.key,
    required this.playbackSliderValue,
    required this.playbackSpeed,
    required this.isPlaying,
    required this.playbackHistoryLength,
    required this.onSliderChanged,
    required this.onSliderStart,
    required this.onPlayPausePressed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (playbackHistoryLength == 0) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Aumentado blur
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Aumentado padding
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Fondo más visible
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            // Efecto glassmorphism sutil
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Play/Pause pequeño y elegante
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onPlayPausePressed,
                ),
              ),
              const SizedBox(width: 12),
              // Slider delgado
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.white.withOpacity(0.8),
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    disabledThumbColor: Colors.white.withOpacity(0.5),
                    disabledActiveTrackColor: Colors.white.withOpacity(0.3),
                    disabledInactiveTrackColor: Colors.white.withOpacity(0.1),
                  ),
                  child: Slider(
                    // CRÍTICO: Sanitizar valor para evitar NaN
                    // Si el valor es NaN o solo hay 1 punto, usar 0.0
                    value: (playbackSliderValue.isNaN || playbackHistoryLength <= 1) 
                        ? 0.0 
                        : playbackSliderValue.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    // Deshabilitar slider si solo hay 1 punto (no hay recorrido para navegar)
                    onChanged: (playbackHistoryLength > 1) ? onSliderChanged : null,
                    onChangeStart: (playbackHistoryLength > 1) ? (_) => onSliderStart() : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Selector de Velocidad (1x, 2x, 4x, 8x, 16x)
              _buildSpeedButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el botón de velocidad con PopupMenuButton (1x, 2x, 4x, 8x, 16x)
  Widget _buildSpeedButton(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: playbackSpeed,
      onSelected: onSpeedChanged,
      child: Container(
        width: 36, // Misma anchura que el botón Play
        height: 36, // Misma altura que el botón Play
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            '${playbackSpeed.toInt()}x',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
        const PopupMenuItem<double>(value: 1.0, child: Text('1x')),
        const PopupMenuItem<double>(value: 2.0, child: Text('2x')),
        const PopupMenuItem<double>(value: 4.0, child: Text('4x')),
        const PopupMenuItem<double>(value: 8.0, child: Text('8x')),
        const PopupMenuItem<double>(value: 16.0, child: Text('16x')),
      ],
    );
  }
}
