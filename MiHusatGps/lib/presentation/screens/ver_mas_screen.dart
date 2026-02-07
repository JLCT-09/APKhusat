import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/share_service.dart';
import '../../core/services/icon_preference_service.dart';
import 'device_details_screen.dart';

/// Pantalla "Ver Más" con opciones adicionales para el dispositivo.
/// 
/// Muestra:
/// - Cabecera con IMEI e ID del dispositivo
/// - Personalización de icono de unidad
/// - Fila de acciones principales (Detalle, Seguimiento, Historial, Comando, Compartir)
class VerMasScreen extends StatefulWidget {
  final DeviceModel device;
  final double latitude;
  final double longitude;
  final VoidCallback? onSeguimiento;
  final VoidCallback? onHistorial;
  final VoidCallback? onComando;
  final VoidCallback? onIconChanged; // Callback para notificar cambio de icono

  const VerMasScreen({
    super.key,
    required this.device,
    required this.latitude,
    required this.longitude,
    this.onSeguimiento,
    this.onHistorial,
    this.onComando,
    this.onIconChanged,
  });

  @override
  State<VerMasScreen> createState() => _VerMasScreenState();
}

class _VerMasScreenState extends State<VerMasScreen> {
  String? _selectedIconName; // Icono seleccionado temporalmente (antes de guardar)
  String? _savedIconName; // Icono guardado actualmente

  @override
  void initState() {
    super.initState();
    _loadSavedIcon();
  }

  /// Carga el icono guardado para el dispositivo
  Future<void> _loadSavedIcon() async {
    final saved = await IconPreferenceService().getIconPreference(widget.device.idDispositivo);
    if (mounted) {
      setState(() {
        _savedIconName = saved;
        _selectedIconName = saved; // Inicializar seleccionado con el guardado
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final hasChanges = _selectedIconName != null && _selectedIconName != _savedIconName;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver Más'),
        backgroundColor: const Color(0xFFEF1A2D), // Color corporativo
        foregroundColor: Colors.white,
        actions: [
          // Botón Guardar con texto en la cabecera (solo visible si hay cambios)
          if (hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _saveIconPreference,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEF1A2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Guardar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Cabecera con IMEI e ID
          _buildHeader(),
          
          const Divider(height: 1, thickness: 0.5),
          
          // Fila de acciones principales (5 botones) - DESPUÉS del IMEI
          _buildActionButtons(context),
          
          const Divider(height: 1, thickness: 0.5),
          
          // Sección de personalización de icono (AL FINAL)
          _buildIconCustomization(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sim_card, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'IMEI: ${widget.device.imei ?? 'No disponible'}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Separador visual
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // ID en la misma fila
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tag, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  'ID: ${widget.device.idDispositivo}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.info_outline,
              label: 'Detalle',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeviceDetailsScreen(
                      device: widget.device,
                      latitude: widget.latitude,
                      longitude: widget.longitude,
                      speedKmh: widget.device.velocidad ?? 0.0,
                      status: _getStatusFromDevice(),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.my_location,
              label: 'Seguimiento',
              onTap: () {
                Navigator.of(context).pop();
                widget.onSeguimiento?.call();
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.history,
              label: 'Historial',
              onTap: () {
                Navigator.of(context).pop();
                widget.onHistorial?.call();
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.settings_remote,
              label: 'Comando',
              onTap: () {
                Navigator.of(context).pop();
                widget.onComando?.call();
              },
            ),
          ),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.share,
              label: 'Compartir',
              onTap: () {
                _shareLocation(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusFromDevice() {
    if (widget.device.idEstadoOperativo == 7) {
      return 'En Movimiento';
    } else if (widget.device.idEstadoOperativo == 6) {
      return 'Estático';
    } else if (widget.device.idEstadoOperativo == 4) {
      return 'Fuera de Línea';
    } else {
      return (widget.device.movimiento ?? false) ? 'En Movimiento' : 'Estático';
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
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

  Future<void> _shareLocation(BuildContext context) async {
    final placa = widget.device.placa ?? 'Sin Placa';
    await ShareService().shareLocation(
      placa: placa,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  Widget _buildIconCustomization(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Text(
                'Personalizar Icono de Unidad',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<String?>(
            future: IconPreferenceService().getIconPreference(widget.device.idDispositivo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Error al cargar iconos',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final currentIcon = snapshot.data ?? 'default';
              
              // Inicializar el icono guardado si es la primera vez
              if (_savedIconName == null) {
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      _savedIconName = currentIcon;
                      _selectedIconName = currentIcon;
                    });
                  }
                });
              }
              
              // GridView con 5 columnas para selección rápida
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, // 5 columnas
                  crossAxisSpacing: 4, // Margen pequeño entre columnas
                  mainAxisSpacing: 4, // Margen pequeño entre filas
                  childAspectRatio: 1.8, // Rectangular horizontal: más ancho que alto (ancho ~40px, alto ~28px)
                ),
                itemCount: IconPreferenceService.availableIcons.length,
                itemBuilder: (context, index) {
                  final iconData = IconPreferenceService.availableIcons[index];
                  final iconName = iconData['name'] as String;
                  final baseAssetPath = iconData['assetPath'] as String?;
                  // Usar el icono seleccionado temporalmente si existe, sino el guardado
                  final isSelected = iconName == (_selectedIconName ?? _savedIconName);
                  
                  // Si está seleccionado, usar la versión azul, sino usar la versión gris
                  final assetPath = isSelected && baseAssetPath != null
                      ? IconPreferenceService.getIconPathByState(iconName, 6, isMap: false) // Estado 6 = Azul
                      : baseAssetPath;
                  
                  return GestureDetector(
                    onTap: () {
                      // Solo seleccionar temporalmente (no guardar aún)
                      setState(() {
                        _selectedIconName = iconName;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4), // Margen pequeño: 2px horizontal, 4px vertical
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: assetPath != null
                          ? Image.asset(
                              assetPath,
                              width: 36, // Tamaño del icono
                              height: 36, // Tamaño del icono
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('❌ Error al cargar icono: $assetPath - $error');
                                // Fallback a la versión gris si la azul no existe
                                if (isSelected && baseAssetPath != null) {
                                  return Image.asset(
                                    baseAssetPath,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.error_outline,
                                        size: 20,
                                        color: isSelected ? Colors.blue : Colors.grey[700],
                                      );
                                    },
                                  );
                                }
                                return Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: isSelected ? Colors.blue : Colors.grey[700],
                                );
                              },
                            )
                          : Icon(
                              Icons.help_outline,
                              size: 20,
                              color: isSelected ? Colors.blue : Colors.grey[700],
                            ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Guarda la preferencia del icono seleccionado
  Future<void> _saveIconPreference() async {
    if (_selectedIconName == null || _selectedIconName == _savedIconName) {
      return; // No hay cambios o ya está guardado
    }

    try {
      await IconPreferenceService().saveIconPreference(
        widget.device.idDispositivo,
        _selectedIconName!,
      );
      
      // Actualizar el icono guardado
      setState(() {
        _savedIconName = _selectedIconName;
      });
      
      // Notificar cambio global (solo para lista de dispositivos, NO para monitor)
      widget.onIconChanged?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Icono actualizado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Cerrar la pantalla después de guardar
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar icono: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

}
