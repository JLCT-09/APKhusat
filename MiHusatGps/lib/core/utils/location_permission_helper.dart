import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import '../../presentation/widgets/location_disclosure_dialog.dart';

/// Helper para manejar permisos de ubicación, incluyendo "Permitir todo el tiempo"
/// necesario para rastreo en segundo plano en Android 10+
class LocationPermissionHelper {
  // CRÍTICO: Lock para evitar solicitudes concurrentes de permisos
  // Esto previene bloqueos y pantallas en blanco causados por múltiples diálogos
  static bool _isRequestingPermission = false;
  /// Verifica y solicita todos los permisos necesarios para rastreo en segundo plano
  /// 
  /// Retorna true si todos los permisos están concedidos, false en caso contrario
  static Future<bool> requestAllLocationPermissions() async {
    // 1. Verificar y solicitar permiso de ubicación básico
    final locationPermission = await Permission.location.status;
    
    if (locationPermission.isDenied) {
      final result = await Permission.location.request();
      if (result.isDenied) {
        debugPrint('❌ Permiso de ubicación denegado');
        return false;
      }
    }
    
    if (locationPermission.isPermanentlyDenied) {
      debugPrint('⚠️ Permiso de ubicación denegado permanentemente. Abrir configuración...');
      await openAppSettings();
      return false;
    }
    
    // 2. Verificar y solicitar permiso de ubicación en segundo plano (Android 10+)
    // Este permiso solo es necesario en Android 10 (API 29) y superior
    if (defaultTargetPlatform == TargetPlatform.android) {
      final backgroundLocationStatus = await Permission.locationAlways.status;
      
      // Si el permiso básico está concedido pero el de segundo plano no, solicitarlo
      if (locationPermission.isGranted && !backgroundLocationStatus.isGranted) {
        debugPrint('📱 Solicitando permiso de ubicación en segundo plano (Permitir todo el tiempo)...');
        final backgroundResult = await Permission.locationAlways.request();
        
        if (backgroundResult.isDenied || backgroundResult.isPermanentlyDenied) {
          debugPrint('⚠️ Permiso de ubicación en segundo plano denegado');
          // Mostrar mensaje explicativo al usuario
          debugPrint('💡 Para rastreo en segundo plano, necesitas "Permitir todo el tiempo" en Configuración');
          return false;
        }
        
        if (backgroundResult.isGranted) {
          debugPrint('✅ Permiso de ubicación en segundo plano concedido');
        }
      }
    }
    
    // 3. Verificar servicio de ubicación habilitado
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        debugPrint('❌ Servicio de ubicación no habilitado');
        return false;
      }
    }
    
    debugPrint('✅ Todos los permisos de ubicación concedidos');
    return true;
  }
  
  /// Verifica si todos los permisos necesarios están concedidos
  static Future<bool> hasAllLocationPermissions() async {
    final locationPermission = await Permission.location.status;
    
    if (!locationPermission.isGranted) {
      return false;
    }
    
    // En Android, verificar también el permiso de segundo plano
    if (defaultTargetPlatform == TargetPlatform.android) {
      final backgroundLocationStatus = await Permission.locationAlways.status;
      if (!backgroundLocationStatus.isGranted) {
        return false;
      }
    }
    
    // Verificar servicio de ubicación
    final location = Location();
    final serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    
    return true;
  }
  
  /// Verifica si solo el permiso básico de ubicación está concedido (sin segundo plano)
  /// OPTIMIZACIÓN: No inicializa Location() si el permiso no está concedido para evitar bloqueos
  static Future<bool> hasBasicLocationPermission() async {
    final locationPermission = await Permission.location.status;
    
    if (!locationPermission.isGranted) {
      return false;
    }
    
    // OPTIMIZACIÓN: Verificar servicio de ubicación solo si el permiso está concedido
    // Esto evita inicializar Location() innecesariamente durante el splash
    try {
      final location = Location();
      final serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [LocationPermissionHelper] Error al verificar servicio de ubicación: $e');
      // Si falla la verificación del servicio, asumir que está habilitado para no bloquear
      return true;
    }
    
    return true;
  }
  
  /// Solicita solo el permiso básico de ubicación (para uso en primer plano)
  static Future<bool> requestBasicLocationPermission() async {
    final locationPermission = await Permission.location.status;
    
    if (locationPermission.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    
    if (locationPermission.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    // Verificar servicio de ubicación
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    
    return locationPermission.isGranted && serviceEnabled;
  }

  /// Solicita SOLO permisos básicos de ubicación con divulgación prominente
  /// NO solicita permisos de segundo plano (esto se hace después del login)
  /// 
  /// [context] - BuildContext para mostrar el diálogo
  /// [onPermissionGranted] - Callback que se ejecuta cuando el permiso básico es concedido
  /// Retorna true si el usuario aceptó, false si rechazó
  static Future<bool> requestBasicLocationPermissionWithDisclosure(
    BuildContext context, {
    VoidCallback? onPermissionGranted,
  }) async {
    debugPrint('🔄 [LocationPermissionHelper] Iniciando solicitud de permisos BÁSICOS con divulgación...');
    
    // CRÍTICO: Verificar primero si ya tiene permisos básicos
    final hasBasic = await hasBasicLocationPermission();
    if (hasBasic) {
      debugPrint('✅ [LocationPermissionHelper] Permisos básicos ya concedidos');
      // Si ya tiene permisos, ejecutar callback inmediatamente
      if (onPermissionGranted != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            onPermissionGranted!();
          });
        });
      }
      return true;
    }
    
    // 1. MOSTRAR DIÁLOGO DE DIVULGACIÓN PROMINENTE PRIMERO
    debugPrint('📱 [LocationPermissionHelper] Mostrando diálogo de divulgación prominente...');
    
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LocationDisclosureDialog(),
    );
    
    debugPrint('📱 [LocationPermissionHelper] Resultado del diálogo: $shouldRequest');
    
    // Si el usuario rechazó, no solicitar permisos (la app ya se cerró)
    if (shouldRequest != true) {
      debugPrint('⚠️ [LocationPermissionHelper] Usuario rechazó la divulgación');
      return false;
    }
    
    // 2. Solicitar SOLO permiso básico (NO segundo plano)
    debugPrint('📱 [LocationPermissionHelper] Solicitando permiso básico de ubicación...');
    
    try {
      final locationPermission = await Permission.location.status;
      debugPrint('📍 [LocationPermissionHelper] Estado permiso básico: $locationPermission');
      
      if (locationPermission.isDenied) {
        final result = await Permission.location.request();
        debugPrint('📍 [LocationPermissionHelper] Resultado solicitud: $result');
        
        if (!result.isGranted) {
          debugPrint('❌ [LocationPermissionHelper] Permiso básico denegado');
          return false;
        }
      }
      
      if (locationPermission.isPermanentlyDenied) {
        debugPrint('⚠️ [LocationPermissionHelper] Permiso denegado permanentemente');
        await openAppSettings();
        return false;
      }
      
      // OPTIMIZACIÓN: Verificar servicio de ubicación solo si el permiso está concedido
      // Esto evita inicializar Location() durante el SplashScreen, lo cual consume recursos de CPU
      // y puede causar congelamiento visual durante la transición
      try {
        final location = Location();
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          debugPrint('📱 [LocationPermissionHelper] Solicitando habilitar servicio de ubicación...');
          serviceEnabled = await location.requestService();
          if (!serviceEnabled) {
            debugPrint('❌ [LocationPermissionHelper] Servicio de ubicación no habilitado');
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [LocationPermissionHelper] Error al verificar servicio de ubicación: $e');
        // Si falla, asumir que está habilitado para no bloquear el flujo
        // El servicio se verificará más tarde cuando realmente se necesite
      }
      
      debugPrint('✅ [LocationPermissionHelper] Permiso básico concedido exitosamente');
      
      // Ejecutar callback para navegar al login
      if (onPermissionGranted != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            debugPrint('📱 [LocationPermissionHelper] Ejecutando callback de navegación...');
            try {
              onPermissionGranted!();
            } catch (e, stackTrace) {
              debugPrint('❌ [LocationPermissionHelper] Error al ejecutar callback: $e');
              debugPrint('📚 Stack trace: $stackTrace');
            }
          });
        });
      }
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [LocationPermissionHelper] Error al solicitar permiso básico: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Solicita permisos de ubicación con divulgación prominente (Prominent Disclosure)
  /// 
  /// Este método muestra el diálogo de divulgación prominente ANTES de solicitar
  /// cualquier permiso de ubicación, cumpliendo con las políticas de Google Play.
  /// 
  /// IMPORTANTE: El diálogo se muestra PRIMERO, y solo si el usuario acepta,
  /// se solicitan los permisos de ubicación básico y en segundo plano.
  /// 
  /// [context] - BuildContext para mostrar el diálogo
  /// [onPermissionsRequested] - Callback opcional que se ejecuta cuando el usuario acepta (antes de solicitar permisos)
  /// Retorna true si el usuario aceptó, false si rechazó
  static Future<bool> requestAllLocationPermissionsWithDisclosure(
    BuildContext context, {
    VoidCallback? onPermissionsRequested,
  }) async {
    debugPrint('🔄 Iniciando solicitud de permisos con divulgación prominente...');
    
    // CRÍTICO: Verificar primero si ya tiene todos los permisos
    final hasAllPermissions = await hasAllLocationPermissions();
    if (hasAllPermissions) {
      debugPrint('✅ Todos los permisos ya están concedidos. Navegando al login...');
      // Si ya tiene permisos, ejecutar callback inmediatamente para navegar al login
      if (onPermissionsRequested != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          onPermissionsRequested!();
        });
      }
      return true;
    }
    
    // 1. MOSTRAR DIÁLOGO DE DIVULGACIÓN PROMINENTE PRIMERO (antes de cualquier permiso)
    debugPrint('📱 Mostrando diálogo de divulgación prominente...');
    
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LocationDisclosureDialog(),
    );
    
    debugPrint('📱 Resultado del diálogo: $shouldRequest');
    
    // Si el usuario rechazó, no solicitar permisos (la app ya se cerró con SystemNavigator.pop())
    if (shouldRequest != true) {
      debugPrint('⚠️ Usuario rechazó la divulgación. La app se cerrará.');
      return false;
    }
    
    // 2. Si el usuario aceptó, ejecutar callback para navegar al login primero
    // Luego solicitar permisos en segundo plano (sin bloquear la navegación)
    debugPrint('✅ Usuario aceptó. Ejecutando callback para navegar al login...');
    
    // Ejecutar callback para navegar al login inmediatamente (después de que el diálogo se cierre)
    if (onPermissionsRequested != null) {
      // Usar WidgetsBinding para asegurar que se ejecute después de que el diálogo se cierre completamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Pequeño delay adicional para asegurar que el diálogo se haya cerrado completamente
        Future.delayed(const Duration(milliseconds: 200), () {
          debugPrint('📱 Ejecutando callback de navegación al login...');
          try {
            onPermissionsRequested!();
          } catch (e, stackTrace) {
            debugPrint('❌ Error al ejecutar callback de navegación: $e');
            debugPrint('📚 Stack trace: $stackTrace');
          }
        });
      });
    }
    
    // Solicitar permisos en segundo plano (sin bloquear la navegación)
    // Esto permite que el usuario vea el login mientras se solicitan los permisos
    _requestPermissionsInBackground();
    
    return true;
  }
  
  /// Solicita SOLO el permiso de ubicación en segundo plano (después del login)
  /// Requiere que el permiso básico ya esté concedido
  /// CRÍTICO: Evita solicitudes concurrentes usando un lock
  /// Retorna true si se concedió, false en caso contrario
  static Future<bool> requestBackgroundLocationPermission() async {
    // CRÍTICO: Verificar si ya hay una solicitud en curso
    if (_isRequestingPermission) {
      debugPrint('⚠️ [LocationPermissionHelper] Ya hay una solicitud de permiso en curso, esperando...');
      // Esperar un momento y retornar false para evitar bloqueos
      await Future.delayed(const Duration(milliseconds: 500));
      return false;
    }
    
    _isRequestingPermission = true;
    debugPrint('📱 [LocationPermissionHelper] Solicitando permiso de segundo plano...');
    
    try {
      // Verificar que el permiso básico esté concedido
      final basicPermission = await Permission.location.status;
      if (!basicPermission.isGranted) {
        debugPrint('⚠️ [LocationPermissionHelper] Permiso básico no concedido, no se puede solicitar segundo plano');
        _isRequestingPermission = false;
        return false;
      }
      
      // Solo en Android
      if (defaultTargetPlatform != TargetPlatform.android) {
        debugPrint('ℹ️ [LocationPermissionHelper] Permiso de segundo plano solo necesario en Android');
        _isRequestingPermission = false;
        return true;
      }
      
      final backgroundStatus = await Permission.locationAlways.status;
      debugPrint('📍 [LocationPermissionHelper] Estado permiso segundo plano: $backgroundStatus');
      
      if (backgroundStatus.isGranted) {
        debugPrint('✅ [LocationPermissionHelper] Permiso de segundo plano ya concedido');
        _isRequestingPermission = false;
        return true;
      }
      
      if (backgroundStatus.isPermanentlyDenied) {
        debugPrint('⚠️ [LocationPermissionHelper] Permiso de segundo plano denegado permanentemente');
        _isRequestingPermission = false;
        return false;
      }
      
      // Solicitar permiso de segundo plano
      debugPrint('📱 [LocationPermissionHelper] Solicitando permiso de ubicación en segundo plano...');
      final result = await Permission.locationAlways.request();
      debugPrint('📍 [LocationPermissionHelper] Resultado solicitud segundo plano: $result');
      
      if (result.isGranted) {
        debugPrint('✅ [LocationPermissionHelper] Permiso de segundo plano concedido');
        _isRequestingPermission = false;
        return true;
      } else {
        debugPrint('⚠️ [LocationPermissionHelper] Permiso de segundo plano denegado');
        _isRequestingPermission = false;
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [LocationPermissionHelper] Error al solicitar permiso de segundo plano: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      _isRequestingPermission = false;
      return false;
    }
  }
  
  /// Solicita permisos de ubicación en segundo plano (sin bloquear la UI)
  static Future<void> _requestPermissionsInBackground() async {
    
    try {
      // 1. Solicitar permiso básico de ubicación primero
      debugPrint('📱 [Background] Solicitando permiso básico de ubicación...');
      final locationPermission = await Permission.location.status;
      debugPrint('📍 [Background] Estado permiso básico: $locationPermission');
      
      if (locationPermission.isDenied) {
        final result = await Permission.location.request();
        if (result.isDenied) {
          debugPrint('❌ [Background] Permiso de ubicación básico denegado');
          return;
        }
      }
      
      if (locationPermission.isPermanentlyDenied) {
        debugPrint('⚠️ [Background] Permiso de ubicación denegado permanentemente');
        return;
      }

      // 2. Verificar servicio de ubicación habilitado
      final location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        debugPrint('📱 [Background] Solicitando habilitar servicio de ubicación...');
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          debugPrint('❌ [Background] Servicio de ubicación no habilitado');
          return;
        }
      }
      
      // 3. Solicitar permiso de ubicación en segundo plano (Android 10+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final currentLocationPermission = await Permission.location.status;
        debugPrint('📍 [Background] Estado actual permiso básico: $currentLocationPermission');
        
        if (currentLocationPermission.isGranted) {
          final backgroundLocationStatus = await Permission.locationAlways.status;
          debugPrint('📍 [Background] Estado permiso segundo plano: $backgroundLocationStatus');
          
          // Si el permiso de segundo plano no está concedido, solicitarlo
          if (!backgroundLocationStatus.isGranted) {
            debugPrint('📱 [Background] Solicitando permiso de ubicación en segundo plano (Permitir todo el tiempo)...');
            final backgroundResult = await Permission.locationAlways.request();
            debugPrint('📍 [Background] Resultado solicitud segundo plano: $backgroundResult');
            
            if (backgroundResult.isGranted) {
              debugPrint('✅ [Background] Permiso de ubicación en segundo plano concedido');
            } else {
              debugPrint('⚠️ [Background] Permiso de ubicación en segundo plano denegado');
            }
          } else {
            debugPrint('✅ [Background] Permiso de segundo plano ya está concedido');
          }
        } else {
          debugPrint('⚠️ [Background] Permiso básico no está concedido, no se puede solicitar segundo plano');
        }
      }
      
      debugPrint('✅ [Background] Proceso de solicitud de permisos completado');
    } catch (e) {
      debugPrint('❌ [Background] Error al solicitar permisos: $e');
    }
  }
}
