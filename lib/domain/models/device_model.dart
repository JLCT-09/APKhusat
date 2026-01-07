/// Estado del dispositivo GPS
enum DeviceStatus { online, offline }

/// Modelo de dispositivo GPS del backend según schema de Swagger.
/// 
/// Representa un dispositivo GPS con toda su información:
/// - idDispositivo (int), nombre, imei, placa
/// - usuarioId, nombreUsuario
/// - Estado (online/offline) basado en ultimaActualizacion
/// - Última ubicación conocida
/// - Velocidad y última actualización
class DeviceModel {
  final int idDispositivo; // Cambiado de String id a int idDispositivo
  final String nombre;
  final String? imei;
  final String? placa;
  final int? usuarioId;
  final String? nombreUsuario;
  final DeviceStatus status;
  final double latitude;
  final double longitude;
  final double speed; // km/h
  final DateTime lastUpdate; // Mapeado desde ultimaActualizacion
  final double? voltaje; // Voltaje en V
  final double? kilometraje; // Kilometraje en km
  final int? bateria; // Porcentaje de batería (0-100)
  final bool? estadoMotor; // true = Encendido, false = Apagado
  final String? modelo; // Modelo del dispositivo (ej: FMB920)

  DeviceModel({
    required this.idDispositivo,
    required this.nombre,
    this.imei,
    this.placa,
    this.usuarioId,
    this.nombreUsuario,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.lastUpdate,
    this.voltaje,
    this.kilometraje,
    this.bateria,
    this.estadoMotor,
    this.modelo,
  });

  /// Crea un DeviceModel desde un JSON del backend según schema de Swagger.
  /// 
  /// Mapea exactamente estos campos: idDispositivo, nombre, imei, placa, 
  /// usuarioId, nombreUsuario y ultimaActualizacion.
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    // IMPORTANTE: Mapear idDispositivo directamente desde json['idDispositivo']
    final idDispositivoValue = json['idDispositivo'];
    final idDispositivoInt = idDispositivoValue is int 
        ? idDispositivoValue 
        : (idDispositivoValue != null ? int.tryParse(idDispositivoValue.toString()) ?? 0 : 0);
    
    // Mapear ultimaActualizacion usando DateTime.parse()
    final ultimaActualizacionStr = json['ultimaActualizacion']?.toString();
    
    DateTime lastUpdate;
    if (ultimaActualizacionStr != null && ultimaActualizacionStr.isNotEmpty) {
      try {
        lastUpdate = DateTime.parse(ultimaActualizacionStr);
      } catch (e) {
        lastUpdate = DateTime.now().subtract(const Duration(hours: 24));
      }
    } else {
      lastUpdate = DateTime.now().subtract(const Duration(hours: 24));
    }
    
    // Determinar si está online (última actualización < 5 minutos)
    final isOnline = DateTime.now().difference(lastUpdate).inMinutes < 5;
    
    return DeviceModel(
      idDispositivo: idDispositivoInt,
      nombre: json['nombre']?.toString() ?? 'Dispositivo Sin Nombre',
      imei: json['imei']?.toString(),
      placa: json['placa']?.toString(),
      usuarioId: json['usuarioId'] is int 
          ? json['usuarioId'] as int
          : (json['usuarioId'] != null ? int.tryParse(json['usuarioId'].toString()) : null),
      nombreUsuario: json['nombreUsuario']?.toString(),
      status: isOnline ? DeviceStatus.online : DeviceStatus.offline,
      latitude: (json['latitud'] ?? json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitud'] ?? json['longitude'] ?? 0.0).toDouble(),
      speed: (json['velocidad'] ?? json['speed'] ?? 0.0).toDouble(),
      lastUpdate: lastUpdate,
      voltaje: json['voltaje'] != null ? (json['voltaje'] as num).toDouble() : null,
      kilometraje: json['kilometraje'] != null ? (json['kilometraje'] as num).toDouble() : null,
      bateria: json['bateria'] != null ? (json['bateria'] is int ? json['bateria'] as int : int.tryParse(json['bateria'].toString())) : null,
      estadoMotor: json['estadoMotor'] != null ? (json['estadoMotor'] as bool) : null,
      modelo: json['modelo']?.toString() ?? 'FMB920',
    );
  }
  
  /// Obtiene el nombre completo del dispositivo (nombre + placa si está disponible)
  String get nombreCompleto {
    if (placa != null && placa!.isNotEmpty) {
      return '$nombre - $placa';
    }
    return nombre;
  }
  
  /// Verifica si la última actualización es muy antigua (> 1 hora)
  bool get isActualizacionAntigua {
    return DateTime.now().difference(lastUpdate).inHours > 1;
  }
}
