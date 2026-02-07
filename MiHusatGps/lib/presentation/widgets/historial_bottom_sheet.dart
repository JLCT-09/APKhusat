import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';

/// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// BottomSheet rediseñado con Glassmorphism para consultar historial
class HistorialBottomSheet extends StatefulWidget {
  final DeviceModel device;
  final Function(DateTime fechaDesde, DateTime fechaHasta, double velocidadReproduccion) onConfirm;

  const HistorialBottomSheet({
    super.key,
    required this.device,
    required this.onConfirm,
  });

  @override
  State<HistorialBottomSheet> createState() => _HistorialBottomSheetState();
}

class _HistorialBottomSheetState extends State<HistorialBottomSheet> {
  double _velocidadReproduccion = 1.0;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _selectedOption = ''; // 'today', 'yesterday', 'last24h', 'custom'
  bool _showCustomPicker = false;
  
  // Variables para el selector personalizado
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();
  TimeOfDay _customStartTime = TimeOfDay.now();
  TimeOfDay _customEndTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _selectToday();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomPicker) {
      return _buildCustomPicker();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Fondo blanco puro
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Sombra sutil
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
                // Barra de arrastre
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.clock,
                        color: _colorCorporativo,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Historial - ${widget.device.placa ?? 'Sin Placa'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Texto negro
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Colors.grey),
                
                // Grid de Periodos (4 botones)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _buildPeriodButton('Hoy', FontAwesomeIcons.calendarDay, 'today'),
                      _buildPeriodButton('Ayer', FontAwesomeIcons.calendar, 'yesterday'),
                      _buildPeriodButton('Últimas 24h', FontAwesomeIcons.clockRotateLeft, 'last24h'),
                      _buildPeriodButton('Definido', FontAwesomeIcons.calendarCheck, 'custom'),
                    ],
                  ),
                ),
                
                // Selector de velocidad de reproducción
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Velocidad de Reproducción',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black, // Texto negro
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSpeedButton(1.0, '1x'),
                          _buildSpeedButton(2.0, '2x'),
                          _buildSpeedButton(4.0, '4x'),
                          _buildSpeedButton(8.0, '8x'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Botones de acción
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.black), // Texto negro
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _canConfirm() ? () => _confirm() : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Azul para resaltar
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'VER RECORRIDO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Construye un botón de periodo con estilo glassmorphism
  Widget _buildPeriodButton(String label, IconData icon, String option) {
    final isSelected = _selectedOption == option;
    
    return InkWell(
      onTap: () => _selectOption(option),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? _colorCorporativo.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _colorCorporativo : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              color: isSelected ? _colorCorporativo : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? _colorCorporativo : Colors.black, // Texto negro
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el selector personalizado con Wheel Pickers (Cupertino) en columnas
  Widget _buildCustomPicker() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white, // Fondo blanco puro
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Sombra sutil
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de arrastre
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título con botón de volver
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black), // Icono negro
                  onPressed: () {
                    setState(() {
                      _showCustomPicker = false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'Definido por Usuario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Texto negro
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.grey),
          
          // Contenido con Wheel Pickers en columnas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bloque de INICIO
                  const Text(
                    'Punto de Partida',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Texto negro
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Columna 1: Selector de Fecha (Wheel Picker)
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: _customStartDate,
                            minimumDate: DateTime(2020),
                            maximumDate: DateTime.now(),
                            onDateTimeChanged: (DateTime newDate) {
                              setState(() {
                                _customStartDate = newDate;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Columna 2: Selector de Hora (Wheel Picker)
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            initialDateTime: DateTime(
                              _customStartDate.year,
                              _customStartDate.month,
                              _customStartDate.day,
                              _customStartTime.hour,
                              _customStartTime.minute,
                            ),
                            use24hFormat: true,
                            onDateTimeChanged: (DateTime newDateTime) {
                              setState(() {
                                _customStartTime = TimeOfDay(
                                  hour: newDateTime.hour,
                                  minute: newDateTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bloque de FIN
                  const Text(
                    'Punto de Llegada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Texto negro
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Columna 1: Selector de Fecha (Wheel Picker)
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: _customEndDate,
                            minimumDate: _customStartDate,
                            maximumDate: DateTime.now(),
                            onDateTimeChanged: (DateTime newDate) {
                              setState(() {
                                _customEndDate = newDate;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Columna 2: Selector de Hora (Wheel Picker)
                      Expanded(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            initialDateTime: DateTime(
                              _customEndDate.year,
                              _customEndDate.month,
                              _customEndDate.day,
                              _customEndTime.hour,
                              _customEndTime.minute,
                            ),
                            use24hFormat: true,
                            onDateTimeChanged: (DateTime newDateTime) {
                              setState(() {
                                _customEndTime = TimeOfDay(
                                  hour: newDateTime.hour,
                                  minute: newDateTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Botón VER RECORRIDO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final fechaDesdeCompleta = DateTime(
                    _customStartDate.year,
                    _customStartDate.month,
                    _customStartDate.day,
                    _customStartTime.hour,
                    _customStartTime.minute,
                    0,
                  );
                  
                  final fechaHastaCompleta = DateTime(
                    _customEndDate.year,
                    _customEndDate.month,
                    _customEndDate.day,
                    _customEndTime.hour,
                    _customEndTime.minute,
                    59,
                  );
                  
                  setState(() {
                    _fechaDesde = fechaDesdeCompleta;
                    _fechaHasta = fechaHastaCompleta;
                    _selectedOption = 'custom';
                    _showCustomPicker = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Azul para resaltar sobre fondo blanco
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'VER RECORRIDO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NOTA: _buildDateTimeButton eliminado - Ahora se usan CupertinoDatePicker directamente

  Widget _buildSpeedButton(double velocidad, String label) {
    final isSelected = _velocidadReproduccion == velocidad;
    return InkWell(
      onTap: () {
        setState(() {
          _velocidadReproduccion = velocidad;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _colorCorporativo : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _colorCorporativo : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black, // Texto negro
          ),
        ),
      ),
    );
  }

  bool _canConfirm() {
    return _fechaDesde != null && _fechaHasta != null;
  }

  void _selectOption(String option) {
    setState(() {
      _selectedOption = option;
      
      if (option == 'custom') {
        _showCustomPicker = true;
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
    final now = DateTime.now();
    setState(() {
      _fechaHasta = now;
      _fechaDesde = now.subtract(const Duration(hours: 24));
      _selectedOption = 'last24h';
    });
  }

  void _confirm() {
    if (_fechaDesde != null && _fechaHasta != null) {
      Navigator.of(context).pop();
      widget.onConfirm(_fechaDesde!, _fechaHasta!, _velocidadReproduccion);
    }
  }
}
