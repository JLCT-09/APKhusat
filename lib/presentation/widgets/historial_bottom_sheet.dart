import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/device_model.dart';

/// BottomSheet para consultar historial con filtros rápidos y reproducción.
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
  double _velocidadReproduccion = 1.0; // Velocidad por defecto: 1x
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _isCustom = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Consulta de Historial - ${widget.device.placa ?? 'Sin Placa'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Botones de filtro rápido
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildFilterButton(
                    icon: Icons.today,
                    label: 'Hoy',
                    onTap: () => _selectToday(),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterButton(
                    icon: Icons.calendar_today,
                    label: 'Ayer',
                    onTap: () => _selectYesterday(),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterButton(
                    icon: Icons.access_time,
                    label: 'Hace 1 hora',
                    onTap: () => _selectLastHour(),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterButton(
                    icon: Icons.settings,
                    label: 'Personalizado',
                    onTap: () => _selectCustom(),
                  ),
                  
                  // Mostrar fechas seleccionadas si es personalizado
                  if (_isCustom && _fechaDesde != null && _fechaHasta != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rango seleccionado:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Desde: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaDesde!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Hasta: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaHasta!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Selector de velocidad de reproducción
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Velocidad de Reproducción',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
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
                ],
              ),
            ),
          ),
          
          // Botones de acción
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
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
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canConfirm() ? () => _confirm() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Consultar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton(double velocidad, String label) {
    final isSelected = _velocidadReproduccion == velocidad;
    return InkWell(
      onTap: () {
        setState(() {
          _velocidadReproduccion = velocidad;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  bool _canConfirm() {
    if (!_isCustom) {
      // Si no es personalizado, siempre puede confirmar (ya tiene fechas)
      return _fechaDesde != null && _fechaHasta != null;
    }
    // Si es personalizado, necesita ambas fechas
    return _fechaDesde != null && _fechaHasta != null;
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _isCustom = false;
      _fechaDesde = DateTime(now.year, now.month, now.day, 0, 0, 0);
      _fechaHasta = now;
    });
  }

  void _selectYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _isCustom = false;
      _fechaDesde = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
      _fechaHasta = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    });
  }

  void _selectLastHour() {
    final now = DateTime.now();
    setState(() {
      _isCustom = false;
      _fechaHasta = now;
      _fechaDesde = now.subtract(const Duration(hours: 1));
    });
  }

  Future<void> _selectCustom() async {
    // Seleccionar fecha y hora de inicio
    final fechaInicio = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _fechaDesde ?? DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.red,
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (fechaInicio == null) return;

    final horaInicio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaDesde ?? DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.red,
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (horaInicio == null) return;

    final fechaDesdeCompleta = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
      horaInicio.hour,
      horaInicio.minute,
      0,
    );

    // Seleccionar fecha y hora de fin
    final fechaFin = await showDatePicker(
      context: context,
      firstDate: fechaDesdeCompleta,
      lastDate: DateTime.now(),
      initialDate: _fechaHasta ?? DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.red,
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (fechaFin == null) return;

    final horaFin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHasta ?? DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.red,
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (horaFin == null) return;

    final fechaHastaCompleta = DateTime(
      fechaFin.year,
      fechaFin.month,
      fechaFin.day,
      horaFin.hour,
      horaFin.minute,
      59,
    );

    setState(() {
      _isCustom = true;
      _fechaDesde = fechaDesdeCompleta;
      _fechaHasta = fechaHastaCompleta;
    });
  }

  void _confirm() {
    if (_fechaDesde != null && _fechaHasta != null) {
      Navigator.of(context).pop();
      widget.onConfirm(_fechaDesde!, _fechaHasta!, _velocidadReproduccion);
    }
  }
}
