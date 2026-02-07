import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/supervision_filter_provider.dart';
import '../../core/utils/storage_service.dart';
import '../../core/services/icon_preference_service.dart';
import '../../data/device_service.dart';
import '../../data/gps_service.dart';
import '../../data/user_service.dart';
import '../../domain/models/device_model.dart';
import '../widgets/device_list_item.dart';
import '../widgets/device_filter_bar.dart';

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

class DevicesScreen extends StatefulWidget {
  final Function(DeviceModel)? onDeviceSelected;
  
  const DevicesScreen({
    super.key,
    this.onDeviceSelected,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _selectedFilter = 'Todos';
  List<DeviceModel> _allDevices = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios en el filtro de supervisión (sincronización con MapScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
      filterProvider.addListener(_onSupervisionFilterChanged);
    });
    
    // Cargar dispositivos al abrir la pantalla por primera vez
    _cargarDispositivos();
    
    // Iniciar timer de actualización automática cada 10 segundos (sincronizado con el Monitor)
    _startAutoRefreshTimer();
    
    // Escuchar cambios en iconos para refrescar la lista
    IconPreferenceService().iconChangedNotifier.addListener(_onIconChanged);
  }

  /// Callback cuando cambia el filtro de supervisión desde el Provider
  void _onSupervisionFilterChanged() {
    if (mounted) {
      // CRÍTICO: Limpiar dispositivos INMEDIATAMENTE antes de cargar nuevos
      // Esto evita confusión mostrando dispositivos del usuario anterior
      setState(() {
        _allDevices = []; // Limpiar lista inmediatamente
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Recargar dispositivos cuando cambia el filtro de supervisión (forzar recarga)
      _cargarDispositivos(forceReload: true);
    }
  }
  
  /// Callback cuando cambia un icono
  void _onIconChanged() {
    if (mounted) {
      // Refrescar la lista para mostrar el nuevo icono
      setState(() {
        // Forzar rebuild de los items de la lista
      });
    }
  }
  
  /// Inicia el timer de actualización automática cada 30 segundos (reducido para evitar parpadeos)
  void _startAutoRefreshTimer() {
    _safeCancelTimer(_refreshTimer, '_refreshTimer');
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading && _allDevices.isNotEmpty) {
        debugPrint('🔄 [Lista] Actualización automática cada 30s (en segundo plano)');
        // Actualizar en segundo plano sin limpiar la lista
        _cargarDispositivos(forceReload: false);
      }
    });
    
    debugPrint('✅ Timer de actualización automática iniciado (30s)');
  }
  
  /// Detiene el timer de actualización automática
  void _stopAutoRefreshTimer() {
    _safeCancelTimer(_refreshTimer, '_refreshTimer');
    _refreshTimer = null;
    debugPrint('⏹️ Timer de actualización automática detenido');
  }

  @override
  void dispose() {
    // BLINDAJE: Cancelar timer de forma segura
    _safeCancelTimer(_refreshTimer, '_refreshTimer');
    _refreshTimer = null;
    
    // Remover listener de cambios de iconos
    IconPreferenceService().iconChangedNotifier.removeListener(_onIconChanged);
    
    // Remover listener del filtro de supervisión
    try {
      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
      filterProvider.removeListener(_onSupervisionFilterChanged);
    } catch (e) {
      debugPrint('⚠️ Error al remover listener del filtro: $e');
    }
    
    super.dispose();
  }

  /// Función de seguridad para cancelar un timer de forma segura
  void _safeCancelTimer(Timer? timer, String timerName) {
    try {
      if (timer != null && timer.isActive) {
        timer.cancel();
        debugPrint('✅ Timer $timerName cancelado correctamente');
      }
    } catch (e) {
      debugPrint('⚠️ Error al cancelar timer $timerName: $e');
    }
  }

  /// Función pública para actualizar dispositivos desde el Monitor
  /// Llamada desde map_screen.dart cuando se presiona el botón de 60s
  Future<void> refreshDevicesFromMonitor() async {
    await _cargarDispositivos();
  }

  /// Carga los dispositivos reales desde el backend usando el UID del usuario logueado.
  Future<void> _cargarDispositivos({bool forceReload = false}) async {
    // Solo limpiar lista si es una recarga forzada (cambio de usuario) o si está vacía
    // Si ya hay datos, actualizar en segundo plano sin limpiar para evitar parpadeos
    if (mounted) {
      if (forceReload || _allDevices.isEmpty) {
        setState(() {
          _allDevices = []; // Limpiar lista solo si es necesario
          _isLoading = true;
          _errorMessage = null;
        });
      } else {
        // Si ya hay datos, actualizar en segundo plano sin mostrar loading
        _isLoading = false; // Mantener false para no mostrar loading
      }
    }

    try {
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
      
      // Obtener filtro de supervisión del Provider
      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);
      final usuarioIdObjetivo = filterProvider.usuarioFiltroId;
      
      final dispositivos = await DeviceService.getDispositivosPorUsuario(
        usuarioIdFinal,
        usuarioIdObjetivo: usuarioIdObjetivo,
      );
      
      // CRÍTICO: Actualizar dispositivos con datos frescos desde /api/estado-dispositivo/{id}
      // Este endpoint tiene los datos más actualizados: movimiento, bateria, energiaExterna, velocidad
      // Sincronizado con el Monitor (map_screen.dart) que usa el mismo endpoint
      List<DeviceModel> updatedDevices = <DeviceModel>[];
      for (final device in dispositivos) {
        try {
          // Llamar a /api/estado-dispositivo/{id} para obtener datos frescos (igual que el Monitor)
          final estado = await GpsService.getEstadoDispositivo(device.idDispositivo.toString());
          
          if (estado != null) {
            // Extraer coordenadas del estado si están disponibles
            double? latFromEstado;
            double? lngFromEstado;
            final lat = estado['latitud'] ?? estado['latitude'];
            final lng = estado['longitud'] ?? estado['longitude'];
            
            if (lat != null && lng != null) {
              final parsedLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
              final parsedLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
              
              if (parsedLat != null && parsedLng != null) {
                latFromEstado = parsedLat;
                lngFromEstado = parsedLng;
              }
            }
            
            // CRÍTICO: Actualizar campo "movimiento" desde el JSON (sincronizado con Monitor)
            final movimientoValue = estado['movimiento'];
            final movimientoBool = movimientoValue != null 
                ? (movimientoValue is bool ? movimientoValue : (movimientoValue.toString().toLowerCase() == 'true'))
                : device.movimiento;
            
            // Extraer otros campos del JSON
            final velocidad = estado['velocidad'] != null
                ? ((estado['velocidad'] is num) 
                    ? estado['velocidad'].toDouble() 
                    : double.tryParse(estado['velocidad'].toString()))
                : device.speed;
            
            final bateria = estado['bateria'] != null
                ? ((estado['bateria'] is num) 
                    ? estado['bateria'].toInt() 
                    : int.tryParse(estado['bateria'].toString()))
                : device.bateria;
            
            final energiaExterna = estado['energiaExterna'] != null
                ? ((estado['energiaExterna'] is num) 
                    ? estado['energiaExterna'].toDouble() 
                    : double.tryParse(estado['energiaExterna'].toString()))
                : device.voltajeExterno;
            
            // CRÍTICO: Extraer rumbo desde el JSON (campo "rumbo": 270)
            final rumbo = estado['rumbo'] != null
                ? ((estado['rumbo'] is num) 
                    ? estado['rumbo'].toDouble() 
                    : double.tryParse(estado['rumbo'].toString()))
                : device.rumbo;
            
            // CRÍTICO: Preservar idEstadoOperativo y codigoEstadoOperativo del dispositivo anterior
            // Solo actualizar si realmente cambió, para evitar que se ponga en plomo (offline) incorrectamente
            int? idEstadoOperativoPreservado = device.idEstadoOperativo;
            String? codigoEstadoOperativoPreservado = device.codigoEstadoOperativo;
            
            // Intentar obtener estado operativo del endpoint, pero preservar el anterior si no se obtiene
            try {
              final estadoOperativo = await GpsService.getEstadoOperativoDispositivo(device.idDispositivo.toString());
              if (estadoOperativo != null && estadoOperativo['idEstadoOperativo'] != null) {
                final rawId = estadoOperativo['idEstadoOperativo'];
                final nuevoIdEstado = (rawId is int) ? rawId : int.tryParse(rawId.toString());
                if (nuevoIdEstado != null) {
                  idEstadoOperativoPreservado = nuevoIdEstado;
                  codigoEstadoOperativoPreservado = estadoOperativo['codigoEstadoOperativo']?.toString() ?? codigoEstadoOperativoPreservado;
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error al obtener estado operativo para dispositivo ${device.idDispositivo}: $e');
              // Si falla, mantener el estado anterior (preservado arriba)
            }
            
            // Crear nuevo DeviceModel con datos actualizados desde /api/estado-dispositivo/{id}
            final updatedDevice = DeviceModel(
              idDispositivo: device.idDispositivo,
              nombre: device.nombre,
              imei: device.imei,
              placa: device.placa,
              usuarioId: device.usuarioId,
              nombreUsuario: device.nombreUsuario,
              status: device.status,
              latitude: latFromEstado ?? device.latitude,
              longitude: lngFromEstado ?? device.longitude,
              speed: velocidad ?? device.speed,
              lastUpdate: device.lastUpdate,
              voltaje: device.voltaje,
              voltajeExterno: energiaExterna ?? device.voltajeExterno,
              kilometrajeTotal: device.kilometrajeTotal,
              bateria: bateria ?? device.bateria, // CRÍTICO: Batería desde estado-dispositivo
              estadoMotor: device.estadoMotor,
              movimiento: movimientoBool, // CRÍTICO: Movimiento desde estado-dispositivo (sincronizado con Monitor)
              rumbo: rumbo, // CRÍTICO: Rumbo desde estado-dispositivo
              modeloGps: device.modeloGps,
              tipo: device.tipo,
              fechaVencimiento: device.fechaVencimiento,
              idEstado: device.idEstado,
              idEstadoOperativo: idEstadoOperativoPreservado, // CRÍTICO: Preservar estado anterior si no cambió
              codigoEstadoOperativo: codigoEstadoOperativoPreservado, // CRÍTICO: Preservar código anterior si no cambió
            );
            
            updatedDevices.add(updatedDevice);
            
            debugPrint('✅ Lista - Dispositivo ${device.idDispositivo}: movimiento=${movimientoBool}, bateria=${bateria}, energiaExterna=${energiaExterna}');
          } else {
            // Si no hay estado, mantener el dispositivo original
            updatedDevices.add(device);
          }
        } catch (e) {
          debugPrint('⚠️ Error al obtener estado del dispositivo ${device.idDispositivo} en lista: $e');
          // Si falla, mantener el dispositivo original
          updatedDevices.add(device);
        }
      }
      
      if (mounted) {
        // Optimización: Solo actualizar si hay cambios significativos
        bool hasSignificantChanges = false;
        
        // Verificar cambios significativos (solo longitud de lista o cambios importantes)
        if (_allDevices.length != updatedDevices.length) {
          hasSignificantChanges = true;
        } else {
          // Solo verificar cambios críticos (no todos los campos para evitar actualizaciones constantes)
          for (int i = 0; i < updatedDevices.length; i++) {
            final oldDevice = i < _allDevices.length ? _allDevices[i] : null;
            final newDevice = updatedDevices[i];
            
            if (oldDevice == null) {
              hasSignificantChanges = true;
              break;
            }
            
            // Solo verificar cambios críticos que afectan la visualización
            if (oldDevice.idEstadoOperativo != newDevice.idEstadoOperativo ||
                oldDevice.latitude != newDevice.latitude ||
                oldDevice.longitude != newDevice.longitude ||
                oldDevice.lastUpdate != newDevice.lastUpdate) {
              hasSignificantChanges = true;
              break;
            }
          }
        }
        
        if (hasSignificantChanges) {
          setState(() {
            _allDevices = updatedDevices;
            _isLoading = false;
          });
          
          // Actualizar estados operativos solo si hay cambios significativos
          _updateDeviceStatuses(silent: true);
        } else {
          // No hay cambios significativos, actualizar datos en segundo plano sin setState
          // Actualizar campos que pueden cambiar sin afectar la visualización principal
          for (int i = 0; i < updatedDevices.length && i < _allDevices.length; i++) {
            final oldDevice = _allDevices[i];
            final newDevice = updatedDevices[i];
            
            // Actualizar campos que cambian frecuentemente pero no requieren rebuild
            if (oldDevice.bateria != newDevice.bateria ||
                oldDevice.voltajeExterno != newDevice.voltajeExterno ||
                oldDevice.speed != newDevice.speed ||
                oldDevice.movimiento != newDevice.movimiento) {
              // Actualizar sin setState para evitar parpadeos
              _allDevices[i] = newDevice;
            }
          }
          
          _isLoading = false;
          // No llamar _updateDeviceStatuses si no hay cambios significativos
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de comunicación con Husat';
          _isLoading = false;
        });
        
        // Solo mostrar snackbar si no hay datos previos
        if (_allDevices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de comunicación con Husat'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  List<DeviceModel> get _filteredDevices {
    switch (_selectedFilter) {
      case 'En Línea':
        // En Línea: idEstadoOperativo 7 (En Movimiento) o 6 (Estático)
        return _allDevices.where((device) {
          final idEstadoOperativo = device.idEstadoOperativo;
          return idEstadoOperativo == 7 || idEstadoOperativo == 6;
        }).toList();
      case 'Fuera de Línea':
        // Fuera de Línea: idEstadoOperativo 4 (Fuera de Línea)
        return _allDevices.where((device) {
          final idEstadoOperativo = device.idEstadoOperativo;
          return idEstadoOperativo == 4;
        }).toList();
      default:
        return _allDevices;
    }
  }

  /// Obtiene el contador de dispositivos para cada filtro según idEstadoOperativo
  int _getFilterCount(String filter) {
    switch (filter) {
      case 'En Línea':
        // En Línea: idEstadoOperativo 7 (En Movimiento) o 6 (Estático)
        return _allDevices.where((device) {
          final idEstadoOperativo = device.idEstadoOperativo;
          return idEstadoOperativo == 7 || idEstadoOperativo == 6;
        }).length;
      case 'Fuera de Línea':
        // Fuera de Línea: idEstadoOperativo 4 (Fuera de Línea)
        return _allDevices.where((device) {
          final idEstadoOperativo = device.idEstadoOperativo;
          return idEstadoOperativo == 4;
        }).length;
      default:
        return _allDevices.length;
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  /// Actualiza los estados operativos (idEstadoOperativo) de todos los dispositivos
  /// Esto permite que los iconos y textos muestren los colores correctos (Verde/Azul/Plomo)
  /// 
  /// [silent] - Si es true, acumula cambios y hace un solo setState al final (evita parpadeos)
  Future<void> _updateDeviceStatuses({bool silent = false}) async {
    if (!mounted || _allDevices.isEmpty) return;
    
    bool hasChanges = false;
    final List<DeviceModel> updatedDevices = List.from(_allDevices);
    
    // Usar Future.wait para cargar todos los estados en paralelo (más rápido)
    final futures = _allDevices.asMap().entries.map((entry) async {
      final index = entry.key;
      final device = entry.value;
      
      try {
        final estado = await GpsService.getEstadoOperativoDispositivo(device.idDispositivo.toString());
        
        if (estado != null && mounted) {
          // Mapeo seguro del ID
          final rawId = estado['idEstadoOperativo'];
          int? idEstadoOperativo;
          
          if (rawId is int) {
            idEstadoOperativo = rawId;
          } else if (rawId is String) {
            idEstadoOperativo = int.tryParse(rawId);
          }
          
          // Actualizar el dispositivo en la lista si el ID cambió
          if (idEstadoOperativo != null && updatedDevices[index].idEstadoOperativo != idEstadoOperativo) {
            // Crear nuevo DeviceModel con idEstadoOperativo actualizado
            updatedDevices[index] = DeviceModel(
              idDispositivo: updatedDevices[index].idDispositivo,
              nombre: updatedDevices[index].nombre,
              imei: updatedDevices[index].imei,
              placa: updatedDevices[index].placa,
              usuarioId: updatedDevices[index].usuarioId,
              nombreUsuario: updatedDevices[index].nombreUsuario,
              status: updatedDevices[index].status,
              latitude: updatedDevices[index].latitude,
              longitude: updatedDevices[index].longitude,
              speed: updatedDevices[index].speed,
              lastUpdate: updatedDevices[index].lastUpdate,
              voltaje: updatedDevices[index].voltaje,
              voltajeExterno: updatedDevices[index].voltajeExterno,
              kilometrajeTotal: updatedDevices[index].kilometrajeTotal,
              bateria: updatedDevices[index].bateria,
              estadoMotor: updatedDevices[index].estadoMotor,
              movimiento: updatedDevices[index].movimiento,
              rumbo: updatedDevices[index].rumbo,
              modeloGps: updatedDevices[index].modeloGps,
              tipo: updatedDevices[index].tipo,
              fechaVencimiento: updatedDevices[index].fechaVencimiento,
              idEstado: updatedDevices[index].idEstado,
              codigoEstadoOperativo: estado['codigoEstadoOperativo']?.toString() ?? updatedDevices[index].codigoEstadoOperativo,
              idEstadoOperativo: idEstadoOperativo, // ACTUALIZADO desde el endpoint
            );
            
            hasChanges = true;
            debugPrint('✅ Estado operativo actualizado para dispositivo ${device.idDispositivo}: idEstadoOperativo=$idEstadoOperativo');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error actualizando estado operativo del dispositivo ${device.idDispositivo}: $e');
      }
    }).toList();
    
    // Esperar a que todas las llamadas terminen
    await Future.wait(futures);
    
    // Solo hacer setState si hubo cambios
    if (hasChanges && mounted) {
      setState(() {
        _allDevices = updatedDevices;
      });
      debugPrint('✅ Estados operativos actualizados para ${_allDevices.length} dispositivos');
    }
  }

  /// Muestra el modal de selección de usuarios para filtro de supervisión
  Future<void> _showUsuarioSelectionModal(BuildContext context) async {
    if (!mounted) return;

    // Verificar que el usuario es admin (rolId == 1)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRolId = authProvider.user?.rolId;
    
    // Si el User no tiene rolId, intentar obtenerlo desde StorageService
    int? rolId = userRolId;
    if (rolId == null) {
      rolId = await StorageService.getUserRolId();
    }
    
    if (rolId != 1) {
      debugPrint('❌ Acceso denegado: Solo usuarios con rolId == 1 (Admin) pueden acceder al filtro de supervisión. RolId actual: $rolId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo administradores pueden acceder a esta función'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      // Cargar lista de usuarios
      final usuarios = await UserService.listarUsuarios();
      
      if (!mounted) return;

      final filterProvider = Provider.of<SupervisionFilterProvider>(context, listen: false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.5, // OPTIMIZACIÓN: Reducido de 0.7 a 0.5
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _colorCorporativo,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Filtro de Supervisión',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Lista de usuarios (sin botón "Ver Mis Dispositivos" - la flecha de regresar ya lo hace)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Lista de usuarios
                    ...usuarios.map((usuario) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorCorporativo.withOpacity(0.1),
                        radius: 24,
                        child: Text(
                          usuario.nombreCompleto.isNotEmpty
                              ? usuario.nombreCompleto[0].toUpperCase()
                              : usuario.nombreUsuario.isNotEmpty
                                  ? usuario.nombreUsuario[0].toUpperCase()
                                  : 'U',
                          style: const TextStyle(
                            color: _colorCorporativo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        usuario.nombreCompleto.isNotEmpty
                            ? usuario.nombreCompleto
                            : usuario.nombreUsuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: usuario.email.isNotEmpty
                          ? Text(
                              usuario.email,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            )
                          : null,
                      trailing: filterProvider.usuarioFiltroId == usuario.id
                          ? const Icon(Icons.check_circle, color: _colorCorporativo, size: 24)
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        filterProvider.setFiltroUsuario(
                          usuario.id,
                          usuario.nombreCompleto.isNotEmpty
                              ? usuario.nombreCompleto
                              : usuario.nombreUsuario,
                        );
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error al cargar usuarios: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuarios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onDeviceTap(DeviceModel device) {
    try {
      // Validar que el dispositivo no sea null y tenga datos válidos
      if (device.idDispositivo <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Dispositivo inválido'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Si hay un callback, usarlo para cambiar al Monitor y enfocar el dispositivo
      if (widget.onDeviceSelected != null) {
        widget.onDeviceSelected!(device);
        return;
      }
      
      // Fallback: validar coordenadas y mostrar mensaje si no hay callback
      if (device.latitude == 0.0 && device.longitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El dispositivo no tiene ubicación disponible'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al seleccionar dispositivo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir dispositivo: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        backgroundColor: _colorCorporativo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Eliminar botón de regreso
        actions: [
          // Botón de filtro de supervisión (solo para admins con rolId == 1)
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final userRolId = authProvider.user?.rolId;
              final isAdmin = userRolId == 1; // Solo rolId == 1 es admin
              if (!isAdmin) return const SizedBox.shrink();
              
              return Consumer<SupervisionFilterProvider>(
                builder: (context, filterProvider, _) {
                  return IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.people_alt),
                        if (filterProvider.tieneFiltroActivo)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 8,
                                minHeight: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: filterProvider.tieneFiltroActivo
                        ? 'Filtro activo: ${filterProvider.usuarioFiltroNombre ?? "Usuario"}'
                        : 'Filtro de Supervisión',
                    onPressed: () => _showUsuarioSelectionModal(context),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros pegada al AppBar sin márgenes
          DeviceFilterBar(
            selectedFilter: _selectedFilter,
            onFilterChanged: _onFilterChanged,
            getFilterCount: _getFilterCount,
          ),
          // Lista de dispositivos
          Expanded(
            child: _isLoading && _allDevices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(_colorCorporativo),
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
                : _errorMessage != null && _allDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: _colorCorporativo.withOpacity(0.7)),
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
                                backgroundColor: _colorCorporativo,
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
                            padding: EdgeInsets.zero,
                            itemCount: _filteredDevices.length,
                            itemBuilder: (context, index) {
                              // OPTIMIZACIÓN: Animación de entrada suave para cada item
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)), // Deslizamiento desde abajo
                                      child: child,
                                    ),
                                  );
                                },
                                child: GestureDetector(
                                  onTap: () => _onDeviceTap(_filteredDevices[index]),
                                  child: DeviceListItem(
                                    device: _filteredDevices[index],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      // BottomNavigationBar ahora se maneja desde MainLayout
    );
  }

}
