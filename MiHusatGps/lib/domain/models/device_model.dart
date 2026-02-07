import 'package:flutter/material.dart';

/// Estado del dispositivo GPS
enum DeviceStatus { online, offline }

/// Estado visual del dispositivo para UI basado en idEstado del backend
enum DeviceVisualStatus { 
  fueraDeLinea,      // idEstado == 1
  enLinea,           // idEstado == 2
  expirado,          // idEstado == 3
  desactivado,       // idEstado == 4 o 5
  estatico,          // idEstado == 6
  enMovimiento,      // idEstado == 7
}

/// Modelo de dispositivo GPS del backend según schema de Swagger.
/// 
/// Representa un dispositivo GPS con toda su información:
/// - idDispositivo (int), nombre, imei, placa
/// - usuarioId, nombreUsuario
/// - Estado (online/offline) basado en ultimaActualizacion
/// - Última ubicación conocida
/// - Velocidad y última actualización
class DeviceModel {
  final int idDispositivo;
  final String nombre;
  final String? imei;
  final String? placa; // Puede ser null
  final int? usuarioId;
  final String? nombreUsuario;
  final DeviceStatus status;
  final double latitude;
  final double longitude;
  double speed; // km/h (mutable para permitir actualizaciones)
  final DateTime lastUpdate; // Mapeado desde ultimaActualizacion
  
  /// Velocidad en km/h (getter/setter para compatibilidad con JSON en español)
  double get velocidad => speed;
  set velocidad(double value) => speed = value;
  final double? voltaje; // Voltaje en V
  final double? voltajeExterno; // Voltaje externo en V (mapeado desde energiaExterna)
  final double? kilometrajeTotal; // Kilometraje total (puede ser null)
  final int? bateria; // Porcentaje de batería (0-100)
  final bool? estadoMotor; // true = Encendido, false = Apagado (mapeado desde "encendido")
  final bool? movimiento; // true = En movimiento, false = Estático (mapeado desde "movimiento")
  final double? rumbo; // Rumbo/heading en grados (0-360) para rotación del icono
  final String? modeloGps; // Modelo del dispositivo GPS (ej: FMC920)
  final String? tipo; // Tipo de vehículo (para determinar icono)
  final DateTime? fechaVencimiento; // Fecha de vencimiento del dispositivo
  final int? idEstado; // ID del estado según tabla oficial del backend
  final String? codigoEstadoOperativo; // Código del estado operativo (ej: "ACTIVO", "INACTIVO")
  final int? idEstadoOperativo; // ID del estado operativo según tabla del backend

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
    this.voltajeExterno,
    this.kilometrajeTotal,
    this.bateria,
    this.estadoMotor,
    this.movimiento,
    this.rumbo,
    this.modeloGps,
    this.tipo,
    this.fechaVencimiento,
    this.idEstado,
    this.codigoEstadoOperativo,
    this.idEstadoOperativo,
  });

  /// Crea un DeviceModel desde un JSON del backend.
  /// 
  /// Mapea exactamente estos campos del JSON:
  /// - idDispositivo, nombre, imei, placa (puede ser null), modeloGps
  /// - ultimaActualizacion (String a DateTime)
  /// - bateria (int), energiaExterna (double), kilometrajeTotal (double/null)
  /// - tipo (para determinar icono)
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    // Debug: Imprimir campos del JSON para verificar qué viene del backend
    if (json.containsKey('idEstado') || json.containsKey('IdEstado')) {
      debugPrint('📊 DeviceModel.fromJson: idEstado = ${json['idEstado'] ?? json['IdEstado']}, NombreEstado = ${json['NombreEstado'] ?? json['nombreEstado']}');
    }
    
    // Mapear idDispositivo
    final idDispositivoValue = json['idDispositivo'];
    final idDispositivoInt = idDispositivoValue is int 
        ? idDispositivoValue 
        : (idDispositivoValue != null ? int.tryParse(idDispositivoValue.toString()) ?? 0 : 0);
    
    // Mapear ultimaActualizacion (String a DateTime)
    // IMPORTANTE: Aplicar conversión UTC-5 (Perú) como en otros servicios
    final ultimaActualizacionStr = json['ultimaActualizacion']?.toString();
    
    DateTime lastUpdate;
    if (ultimaActualizacionStr != null && ultimaActualizacionStr.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(ultimaActualizacionStr);
        // Si no tiene zona horaria, asumir UTC
        if (!ultimaActualizacionStr.contains('Z') && 
            !ultimaActualizacionStr.contains('+') && 
            !ultimaActualizacionStr.contains('-', 10)) {
          parsedDate = parsedDate.toUtc();
        }
        // Aplicar UTC-5 (Perú) para convertir a hora local
        lastUpdate = parsedDate.subtract(const Duration(hours: 5));
      } catch (e) {
        debugPrint('⚠️ Error al parsear ultimaActualizacion: $e');
        lastUpdate = DateTime.now().subtract(const Duration(hours: 24));
      }
    } else {
      lastUpdate = DateTime.now().subtract(const Duration(hours: 24));
    }
    
    // Mapear fechaVencimiento (String a DateTime, puede ser null)
    DateTime? fechaVencimiento;
    final fechaVencimientoStr = json['fechaVencimiento']?.toString();
    if (fechaVencimientoStr != null && fechaVencimientoStr.isNotEmpty) {
      try {
        fechaVencimiento = DateTime.parse(fechaVencimientoStr);
      } catch (e) {
        fechaVencimiento = null;
      }
    }
    
    // Determinar si está online (última actualización < 5 minutos)
    final isOnline = DateTime.now().difference(lastUpdate).inMinutes < 5;
    
    // Mapear velocidad desde el campo "velocidad" del JSON
    final velocidad = (json['velocidad'] ?? json['speed'] ?? 0.0).toDouble();
    
    // Mapear bateria desde el campo "bateria" del JSON
    final bateriaValue = json['bateria'];
    final bateriaInt = bateriaValue != null 
        ? (bateriaValue is int ? bateriaValue : (bateriaValue is num ? bateriaValue.toInt() : int.tryParse(bateriaValue.toString())))
        : null;
    
    // Mapear movimiento desde el campo "movimiento" del JSON (bool)
    final movimientoValue = json['movimiento'];
    final movimientoBool = movimientoValue != null 
        ? (movimientoValue is bool ? movimientoValue : (movimientoValue.toString().toLowerCase() == 'true'))
        : null;
    
    // Mapear encendido desde el campo "encendido" del JSON (bool)
    // También acepta "estadoMotor" para compatibilidad
    final encendidoValue = json['encendido'] ?? json['estadoMotor'];
    final encendidoBool = encendidoValue != null 
        ? (encendidoValue is bool ? encendidoValue : (encendidoValue.toString().toLowerCase() == 'true'))
        : null;
    
    return DeviceModel(
      idDispositivo: idDispositivoInt,
      nombre: json['nombre']?.toString() ?? 'Dispositivo Sin Nombre',
      imei: json['imei']?.toString() ?? '',
      placa: json['placa']?.toString() ?? '',
      usuarioId: json['usuarioId'] is int 
          ? json['usuarioId'] as int
          : (json['usuarioId'] != null ? int.tryParse(json['usuarioId'].toString()) : null),
      nombreUsuario: json['nombreUsuario']?.toString() ?? '',
      status: isOnline ? DeviceStatus.online : DeviceStatus.offline,
      latitude: (json['latitud'] ?? json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitud'] ?? json['longitude'] ?? 0.0).toDouble(),
      speed: velocidad,
      lastUpdate: lastUpdate,
      voltaje: json['voltaje'] != null ? (json['voltaje'] as num).toDouble() : null,
      voltajeExterno: json['energiaExterna'] != null ? (json['energiaExterna'] as num).toDouble() : null,
      kilometrajeTotal: json['kilometrajeTotal'] != null ? (json['kilometrajeTotal'] as num).toDouble() : null,
      bateria: bateriaInt,
      estadoMotor: encendidoBool,
      movimiento: movimientoBool,
      rumbo: json['rumbo'] != null ? (json['rumbo'] as num).toDouble() : null,
      modeloGps: json['modeloGps']?.toString() ?? 'FMB920',
      tipo: json['tipo']?.toString() ?? '',
      fechaVencimiento: fechaVencimiento,
      idEstado: json['idEstado'] != null 
          ? (json['idEstado'] is int ? json['idEstado'] as int : int.tryParse(json['idEstado'].toString()))
          : (json['IdEstado'] != null 
              ? (json['IdEstado'] is int ? json['IdEstado'] as int : int.tryParse(json['IdEstado'].toString()))
              : null), // Si no viene idEstado, será null y se usará lógica de fallback
      codigoEstadoOperativo: json['codigoEstadoOperativo']?.toString(),
      idEstadoOperativo: json['idEstadoOperativo'] != null
          ? (json['idEstadoOperativo'] is int 
              ? json['idEstadoOperativo'] as int 
              : int.tryParse(json['idEstadoOperativo'].toString()))
          : null,
    );
  }
  
  /// Obtiene el nombre completo del dispositivo (nombre + placa si está disponible)
  String get nombreCompleto {
    if (placa != null && placa!.isNotEmpty && placa != '') {
      return '$nombre - $placa';
    }
    return nombre;
  }
  
  /// Verifica si la última actualización es muy antigua (> 1 hora)
  bool get isActualizacionAntigua {
    return DateTime.now().difference(lastUpdate).inHours > 1;
  }
  
  /// Determina el estado visual del dispositivo usando el campo "movimiento" del JSON
  /// 
  /// LÓGICA ÚNICA (Sincronizada entre Lista de Dispositivos y Monitor):
  /// VERDE (carro_verde.png): Si movimiento == true (definido por el backend)
  /// AZUL (carro_azul.png): Si movimiento == false (definido por el backend)
  DeviceVisualStatus get visualStatus {
    // Usar el campo "movimiento" directamente del JSON
    final enMovimiento = movimiento ?? false;
    
    // VERDE: Si el campo "movimiento" es true
    if (enMovimiento) {
      return DeviceVisualStatus.enMovimiento; // VERDE - En movimiento
    }
    
    // AZUL: Si el campo "movimiento" es false
    return DeviceVisualStatus.estatico; // AZUL - Estático
  }
  
  /// Obtiene el color del estado para UI
  /// Solo 2 colores: Verde (movimiento), Azul (todos los demás casos)
  Color get colorEstado {
    switch (visualStatus) {
      case DeviceVisualStatus.enMovimiento:
        return Colors.green;
      case DeviceVisualStatus.estatico:
      case DeviceVisualStatus.enLinea:
      case DeviceVisualStatus.fueraDeLinea:
      case DeviceVisualStatus.expirado:
      case DeviceVisualStatus.desactivado:
        return Colors.blue; // Azul para todos los demás casos
    }
  }
  
  /// Obtiene el texto del estado para UI según idEstado
  String get textoEstado {
    switch (visualStatus) {
      case DeviceVisualStatus.fueraDeLinea: // idEstado == 1
        return 'Fuera de Línea';
      case DeviceVisualStatus.enLinea: // idEstado == 2
        return speed == 0 ? 'Estático' : 'En Línea';
      case DeviceVisualStatus.expirado: // idEstado == 3
        return 'Vencido';
      case DeviceVisualStatus.desactivado: // idEstado == 4 o 5
        return idEstado == 4 ? 'Desactivado' : 'Bloqueado';
      case DeviceVisualStatus.estatico: // idEstado == 6
        return 'Estático';
      case DeviceVisualStatus.enMovimiento: // idEstado == 7
        return 'En Movimiento';
    }
  }
  
  /// Obtiene el icono del vehículo según el campo tipo
  IconData get iconoVehiculo {
    if (tipo != null && tipo!.isNotEmpty && tipo != '') {
      // Mapear tipos comunes a iconos
      final tipoLower = tipo!.toLowerCase();
      if (tipoLower.contains('camion') || tipoLower.contains('truck')) {
        return Icons.local_shipping;
      } else if (tipoLower.contains('auto') || tipoLower.contains('car')) {
        return Icons.directions_car;
      } else if (tipoLower.contains('moto') || tipoLower.contains('motorcycle')) {
        return Icons.two_wheeler;
      } else if (tipoLower.contains('bus')) {
        return Icons.directions_bus;
      }
    }
    // Icono por defecto
    return Icons.directions_car;
  }
  
  /// Compatibilidad: modelo (alias de modeloGps)
  String? get modelo => modeloGps;
  
  /// Compatibilidad: kilometraje (alias de kilometrajeTotal)
  double? get kilometraje => kilometrajeTotal;
  
  /// Compatibilidad: energiaExterna (alias de voltajeExterno)
  /// El JSON de Swagger usa "energiaExterna" pero el modelo interno usa "voltajeExterno"
  double? get energiaExterna => voltajeExterno;
}
