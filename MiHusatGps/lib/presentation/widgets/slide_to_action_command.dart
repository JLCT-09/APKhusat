import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// Widget de deslizamiento para comandos de vehículo
/// 
/// Soporta dos direcciones:
/// - Izquierda a Derecha: Apagar Motor (rojo)
/// - Derecha a Izquierda: Restaurar Motor (verde)
class SlideToActionCommand extends StatefulWidget {
  final String commandType; // 'apagar' o 'restaurar'
  final VoidCallback onSlideComplete;

  const SlideToActionCommand({
    super.key,
    required this.commandType,
    required this.onSlideComplete,
  });

  @override
  State<SlideToActionCommand> createState() => _SlideToActionCommandState();
}

class _SlideToActionCommandState extends State<SlideToActionCommand>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  final double _thumbSize = 60.0;
  final double _threshold = 0.85; // 85% del recorrido para activar
  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void resetSlider() {
    setState(() {
      _dragPosition = 0.0;
      _isCompleted = false;
    });
    _animationController.reset();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isCompleted) return;

    setState(() {
      // Obtener ancho actual del slider
      final RenderBox? renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
      final currentWidth = renderBox?.size.width ?? 300.0;
      final maxDrag = currentWidth - _thumbSize - 10;
      
      if (widget.commandType == 'apagar') {
        // Deslizar de izquierda a derecha
        _dragPosition = math.max(
          0.0,
          math.min(
            maxDrag,
            _dragPosition + details.delta.dx,
          ),
        );
      } else {
        // Deslizar de derecha a izquierda
        _dragPosition = math.max(
          0.0,
          math.min(
            maxDrag,
            _dragPosition - details.delta.dx,
          ),
        );
      }
      
      // Verificar si se completó el recorrido
      final progress = maxDrag > 0 ? _dragPosition / maxDrag : 0.0;
      if (progress >= _threshold && !_isCompleted) {
        _isCompleted = true;
        HapticFeedback.mediumImpact();
        _animationController.forward();
        // Llamar al callback para solicitar contraseña
        widget.onSlideComplete();
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isCompleted) {
      // Si no se completó, volver a la posición inicial
      _animationController.forward().then((_) {
        resetSlider();
      });
    }
  }

  Color get _backgroundColor {
    if (!_isCompleted) return Colors.grey[200]!;
    return widget.commandType == 'apagar' ? _colorCorporativo : Colors.green;
  }

  IconData get _icon {
    if (!_isCompleted) {
      return widget.commandType == 'apagar' ? Icons.power_off : Icons.power_settings_new;
    }
    return widget.commandType == 'apagar' ? Icons.lock : Icons.bolt;
  }

  String get _label {
    if (!_isCompleted) {
      return widget.commandType == 'apagar' ? 'Desliza para Apagar' : 'Desliza para Restaurar';
    }
    return widget.commandType == 'apagar' ? 'Motor Apagado' : 'Motor Restaurado';
  }

  @override
  Widget build(BuildContext context) {
    final isLeftToRight = widget.commandType == 'apagar';

    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxWidth;
        final maxDrag = sliderWidth - _thumbSize - 10; // 10px de padding
        
        return Container(
          key: _containerKey,
          width: double.infinity,
          height: 70,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
        children: [
          // Texto de fondo
          Center(
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isCompleted ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
          // Thumb deslizable
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                left: isLeftToRight ? _dragPosition : null,
                right: isLeftToRight ? null : _dragPosition,
                top: 5,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _icon,
                      color: _isCompleted
                          ? (widget.commandType == 'apagar' ? _colorCorporativo : Colors.green)
                          : Colors.grey[600],
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
          ],
        ),
      );
      },
    );
  }
}
