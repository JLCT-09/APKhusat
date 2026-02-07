import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';

/// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// Ventana emergente personalizada para consultar historial
/// Reemplaza el BottomSheet con un diseño más elegante y selectores deslizantes
class HistorialDialog extends StatefulWidget {
  final DeviceModel device;
  final Function(DateTime fechaDesde, DateTime fechaHasta, double velocidadReproduccion) onConfirm;

  const HistorialDialog({
    super.key,
    required this.device,
    required this.onConfirm,
  });

  @override
  State<HistorialDialog> createState() => _HistorialDialogState();
}

class _HistorialDialogState extends State<HistorialDialog> {
  double _velocidadReproduccion = 1.0;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _selectedOption = 'today'; // 'today', 'yesterday', 'last24h', 'custom'
  bool _showCustomPicker = false;
  
  // Variables para el selector personalizado
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();
  int _customStartHour = 0;
  int _customStartMinute = 0;
  int _customEndHour = 23;
  int _customEndMinute = 59;

  @override
  void initState() {
    super.initState();
    _selectToday();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Fondo blanco puro
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3), // Borde gris fino
              width: 0.5,
            ),
          ),
          child: _showCustomPicker ? _buildCustomPicker() : _buildMainContent(),
        ),
      ),
    );
  }

  /// Contenido principal con opciones rápidas
  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding reducido
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila 1: Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial',
                  style: TextStyle(
                    fontSize: 14, // Tamaño reducido
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Texto negro
                  ),
                ),
                Text(
                  widget.device.placa ?? 'Sin Placa',
                  style: const TextStyle(
                    fontSize: 14, // Tamaño reducido
                    fontWeight: FontWeight.bold,
                    color: _colorCorporativo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Espaciado reducido
            
            // Fila 2: Botón "Hoy"
            _buildOptionRow('Hoy', 'today'),
            const SizedBox(height: 8), // Espaciado reducido
            
            // Fila 3: Botón "Ayer"
            _buildOptionRow('Ayer', 'yesterday'),
            const SizedBox(height: 8), // Espaciado reducido
            
            // Fila 4: Botón "Últimas 24h"
            _buildOptionRow('Últimas 24h', 'last24h'),
            const SizedBox(height: 8), // Espaciado reducido
            
            // Fila 5: Botón "Definido por el Usuario"
            _buildOptionRow('Definido por el Usuario', 'custom'),
            
            // Si está seleccionado "custom", mostrar configuración expandida
            if (_selectedOption == 'custom') ...[
              const SizedBox(height: 12), // Espaciado reducido
              _buildCustomDateTimeSelector(),
            ],
            
            const SizedBox(height: 16), // Espaciado reducido
            
            // Botón de acción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm() ? () => _confirm() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorCorporativo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12), // Padding reducido
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'VER RECORRIDO',
                  style: TextStyle(
                    fontSize: 14, // Tamaño reducido
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8), // Espaciado reducido
            
            // Botón cancelar
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87, // Texto negro
                  padding: const EdgeInsets.symmetric(vertical: 8), // Padding reducido
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 12), // Tamaño reducido
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una fila de opción con radio button circular
  Widget _buildOptionRow(String label, String option) {
    final isSelected = _selectedOption == option;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedOption = option;
          if (option == 'custom') {
            _showCustomPicker = false; // Mostrar selector inline
          } else {
            _showCustomPicker = false;
            switch (option) {
              case 'today':
                _selectToday();
                break;
              case 'yesterday':
                _selectYesterday();
                break;
              case 'last24h':
                _selectLast24Hours();
                break;
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Padding reducido
        decoration: BoxDecoration(
          color: isSelected 
              ? _colorCorporativo.withOpacity(0.1) // Fondo rojo muy claro cuando seleccionado
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? _colorCorporativo.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2), // Borde gris claro cuando no seleccionado
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Radio button circular
            Container(
              width: 16, // Tamaño reducido
              height: 16, // Tamaño reducido
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _colorCorporativo : Colors.grey.withOpacity(0.4), // Gris claro cuando inactivo
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? _colorCorporativo : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 8, // Punto rojo pequeño
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12), // Espaciado reducido
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12, // Tamaño reducido
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.black, // Texto negro
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de fecha y hora personalizado (expandido)
  Widget _buildCustomDateTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(12), // Padding reducido
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05), // Fondo gris muy claro
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2), // Borde gris claro
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Punto de Inicio
          const Text(
            'Punto de Inicio',
            style: TextStyle(
              fontSize: 12, // Tamaño reducido
              fontWeight: FontWeight.w600,
              color: Colors.black87, // Texto negro
            ),
          ),
          const SizedBox(height: 8), // Espaciado reducido
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  label: 'Fecha',
                  date: _customStartDate,
                  onDateChanged: (date) {
                    setState(() {
                      _customStartDate = date;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeSelector(
                  label: 'Hora',
                  hour: _customStartHour,
                  minute: _customStartMinute,
                  onTimeChanged: (hour, minute) {
                    setState(() {
                      _customStartHour = hour;
                      _customStartMinute = minute;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12), // Espaciado reducido
          
          // Punto de Llegada
          const Text(
            'Punto de Llegada',
            style: TextStyle(
              fontSize: 12, // Tamaño reducido
              fontWeight: FontWeight.w600,
              color: Colors.black87, // Texto negro
            ),
          ),
          const SizedBox(height: 8), // Espaciado reducido
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  label: 'Fecha',
                  date: _customEndDate,
                  onDateChanged: (date) {
                    setState(() {
                      _customEndDate = date;
                    });
                  },
                  minDate: _customStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeSelector(
                  label: 'Hora',
                  hour: _customEndHour,
                  minute: _customEndMinute,
                  onTimeChanged: (hour, minute) {
                    setState(() {
                      _customEndHour = hour;
                      _customEndMinute = minute;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Selector de fecha con CupertinoDatePicker
  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required Function(DateTime) onDateChanged,
    DateTime? minDate,
  }) {
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => Container(
            height: 200, // Altura reducida
            color: Colors.white, // Fondo blanco
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Padding reducido
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05), // Fondo gris muy claro
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.2)), // Borde gris claro
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Confirmar', style: TextStyle(color: _colorCorporativo)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: date,
                    minimumDate: minDate ?? DateTime(2020),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: onDateChanged,
                    backgroundColor: Colors.white, // Fondo blanco
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Padding reducido
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05), // Fondo gris muy claro
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2), // Borde gris claro
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10, // Tamaño reducido
                color: Colors.black54, // Texto gris oscuro
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                fontSize: 12, // Tamaño reducido
                color: Colors.black, // Texto negro
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de hora con ListWheelScrollView
  Widget _buildTimeSelector({
    required String label,
    required int hour,
    required int minute,
    required Function(int, int) onTimeChanged,
  }) {
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => Container(
            height: 200, // Altura reducida
            color: Colors.white, // Fondo blanco
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Padding reducido
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05), // Fondo gris muy claro
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.2)), // Borde gris claro
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Confirmar', style: TextStyle(color: _colorCorporativo)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: hour),
                          itemExtent: 35, // Altura reducida
                          onSelectedItemChanged: (index) {
                            onTimeChanged(index, minute);
                          },
                          children: List.generate(24, (index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(color: Colors.black, fontSize: 16), // Texto negro, tamaño reducido
                              ),
                            );
                          }),
                          backgroundColor: Colors.white, // Fondo blanco
                        ),
                      ),
                      const Text(':', style: TextStyle(color: Colors.black, fontSize: 16)), // Texto negro
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: minute),
                          itemExtent: 35, // Altura reducida
                          onSelectedItemChanged: (index) {
                            onTimeChanged(hour, index);
                          },
                          children: List.generate(60, (index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(color: Colors.black, fontSize: 16), // Texto negro, tamaño reducido
                              ),
                            );
                          }),
                          backgroundColor: Colors.white, // Fondo blanco
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Padding reducido
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05), // Fondo gris muy claro
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2), // Borde gris claro
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10, // Tamaño reducido
                color: Colors.black54, // Texto gris oscuro
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12, // Tamaño reducido
                color: Colors.black, // Texto negro
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista del selector personalizado completo (no se usa, se muestra inline)
  Widget _buildCustomPicker() {
    return _buildMainContent(); // Reutilizar el contenido principal
  }

  bool _canConfirm() {
    return _fechaDesde != null && _fechaHasta != null;
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _fechaDesde = DateTime(now.year, now.month, now.day, 0, 0, 0);
      _fechaHasta = now;
      _selectedOption = 'today';
    });
  }

  void _selectYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _fechaDesde = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
      _fechaHasta = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      _selectedOption = 'yesterday';
    });
  }

  void _selectLast24Hours() {
    // CRÍTICO: Calcular "Últimas 24 horas" desde ahora hacia atrás
    // Esto asegura que se obtengan los recorridos más recientes
    final now = DateTime.now();
    setState(() {
      _fechaHasta = now;
      // Restar exactamente 24 horas desde ahora (no desde inicio del día)
      _fechaDesde = now.subtract(const Duration(hours: 24));
      _selectedOption = 'last24h';
    });
    debugPrint('📅 Últimas 24h seleccionadas: desde ${_fechaDesde?.toString()} hasta ${_fechaHasta?.toString()}');
  }

  void _confirm() {
    if (_selectedOption == 'custom') {
      // Construir fechas completas desde los selectores personalizados
      _fechaDesde = DateTime(
        _customStartDate.year,
        _customStartDate.month,
        _customStartDate.day,
        _customStartHour,
        _customStartMinute,
        0,
      );
      
      _fechaHasta = DateTime(
        _customEndDate.year,
        _customEndDate.month,
        _customEndDate.day,
        _customEndHour,
        _customEndMinute,
        59,
      );
    }
    
    if (_fechaDesde != null && _fechaHasta != null) {
      Navigator.of(context).pop();
      widget.onConfirm(_fechaDesde!, _fechaHasta!, _velocidadReproduccion);
    }
  }
}
