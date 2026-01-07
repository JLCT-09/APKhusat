import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/storage_service.dart';
import '../../data/device_service.dart';
import '../../domain/models/device_model.dart' show DeviceModel, DeviceStatus;

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _selectedFilter = 'Todos'; // Filtro seleccionado
  List<DeviceModel> _allDevices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDispositivos();
  }

  /// Carga los dispositivos reales desde el backend usando el UID del usuario logueado.
  /// 
  /// FILTRO POR USUARIO (Seguridad): Solo muestra dispositivos asignados al usuario logueado.
  /// Usa el userId obtenido del login para llamar a GET /api/dispositivos/por-usuario/{userId}
  Future<void> _cargarDispositivos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener UID del usuario desde el almacenamiento (extraído del token JWT)
      final userId = await StorageService.getUserId();
      
      String usuarioIdFinal = '';
      
      if (userId != null && userId.isNotEmpty) {
        usuarioIdFinal = userId;
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;
        if (user != null && user.id.isNotEmpty) {
          usuarioIdFinal = user.id;
        } else {
          throw Exception('Usuario no autenticado. Por favor, inicia sesión nuevamente.');
        }
      }
      
      if (usuarioIdFinal.isEmpty) {
        throw Exception('No se pudo obtener el ID del usuario');
      }
      
      // Esta es la única fuente de datos para la lista de Dispositivos
      final dispositivos = await DeviceService.getDispositivosPorUsuario(usuarioIdFinal);
      
      setState(() {
        _allDevices = dispositivos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de comunicación con Husat';
        _isLoading = false;
      });
      
      if (mounted) {
        // Extraer código de error si está disponible
        String mensajeError = 'Error de comunicación con Husat';
        if (e.toString().contains('Código:')) {
          mensajeError = e.toString().replaceFirst('Exception: ', '');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  List<DeviceModel> get _filteredDevices {
    switch (_selectedFilter) {
      case 'En Línea':
        return _allDevices.where((device) => device.status == DeviceStatus.online).toList();
      case 'Fuera de Línea':
        return _allDevices.where((device) => device.status == DeviceStatus.offline).toList();
      default:
        return _allDevices;
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _onDeviceTap(DeviceModel device) {
    // Retornar el dispositivo seleccionado al MapScreen
    Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Fila de filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton('Todos', _selectedFilter == 'Todos'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterButton('En Línea', _selectedFilter == 'En Línea'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterButton('Fuera de Línea', _selectedFilter == 'Fuera de Línea'),
                ),
              ],
            ),
          ),
          // Lista de dispositivos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando dispositivos desde Husat...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _cargarDispositivos,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _filteredDevices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.devices_other,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tienes dispositivos vinculados a tu cuenta de Gerente',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Text(
                                    'Contacta con el administrador para que asigne dispositivos a tu cuenta',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _filteredDevices.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _onDeviceTap(_filteredDevices[index]),
                                child: _buildDeviceCard(_filteredDevices[index]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    return ElevatedButton(
      onPressed: () => _onFilterChanged(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.red : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    final isOnline = device.status == DeviceStatus.online;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icono de vehículo en rojo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Información del dispositivo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del vehículo en negrita
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Icono de advertencia si la actualización es muy antigua
                      if (device.isActualizacionAntigua)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.orange[700],
                          ),
                        ),
                      // Círculo de estado
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'En Línea' : 'Fuera de Línea',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Placa justo debajo del nombre
                  if (device.placa != null && device.placa!.isNotEmpty)
                    Text(
                      'Placa: ${device.placa}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Última ubicación
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Lat: ${device.latitude.toStringAsFixed(6)}, Lng: ${device.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Velocidad actual
                  Row(
                    children: [
                      const Icon(
                        Icons.speed,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Velocidad: ${device.speed.toStringAsFixed(1)} km/h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
