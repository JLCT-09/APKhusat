import 'package:flutter/material.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/location_permission_helper.dart';
import 'login_screen.dart';

/// Pantalla de carga inicial con logo y nombre de la aplicación.
/// 
/// Muestra:
/// - Logo grande (240px de altura) desde assets/images/LogoCarga.png
/// - Texto "Husat365" debajo del logo
/// - Subtítulo "Seguridad Vehicular"
/// - Animación FadeIn suave
/// - Duración mínima de 2.5 segundos antes de navegar al Login
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false; // Bandera para evitar doble navegación

  @override
  void initState() {
    super.initState();
    
    // Configurar animación FadeIn
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    // Iniciar animación
    _animationController.forward();
    
    // OPTIMIZACIÓN: Precargar iconos críticos en segundo plano mientras se muestra el splash
    _preloadCriticalIcons();
    
    // CRÍTICO: Solicitar permisos ANTES de navegar al LoginScreen (como versión Azure)
    // El diálogo modal bloqueante "despierta" el sistema de renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Esperar a que la animación se complete y luego solicitar permisos
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_isNavigating) {
          debugPrint('🚀 [SplashScreen] Iniciando solicitud de permisos antes de LoginScreen...');
          _requestLocationPermissionsAndNavigate();
        }
      });
    });
  }

  /// Precarga iconos críticos en segundo plano para mejorar rendimiento
  /// 
  /// OPTIMIZACIÓN: Carga los iconos más usados antes de que se necesiten
  Future<void> _preloadCriticalIcons() async {
    try {
      debugPrint('🔄 Precargando iconos críticos...');
      final criticalIcons = [
        'assets/images/carro_verde.png',
        'assets/images/carro_azul.png',
        'assets/images/carro_plomo.png',
      ];
      
      // Precargar en paralelo sin bloquear la UI
      await Future.wait(
        criticalIcons.map((path) => IconHelper.loadPngFromAsset(path).catchError((e) {
          debugPrint('⚠️ Error al precargar icono $path: $e');
          return null; // Retornar null en caso de error
        })),
      );
      
      debugPrint('✅ Iconos críticos precargados exitosamente');
    } catch (e) {
      debugPrint('⚠️ Error al precargar iconos críticos: $e');
      // No bloquear la navegación si falla la precarga
    }
  }
  
  /// Solicita SOLO permisos básicos de ubicación, luego navega al Login
  /// CRÍTICO: El diálogo modal bloqueante "despierta" el sistema de renderizado
  /// Esto es necesario para que el LoginScreen se renderice correctamente
  Future<void> _requestLocationPermissionsAndNavigate() async {
    if (!mounted || _isNavigating) {
      debugPrint('⚠️ [SplashScreen] Widget no montado o ya navegando, abortando...');
      return;
    }
    
    // CRÍTICO: Esperar a que la animación de entrada se complete completamente
    if (!_animationController.isCompleted) {
      await _animationController.forward().then((_) {
        debugPrint('✅ [SplashScreen] Animación de entrada completada');
      });
    } else {
      debugPrint('✅ [SplashScreen] Animación de entrada ya estaba completada');
    }
    
    if (!mounted || _isNavigating) return;
    
    debugPrint('🔍 [SplashScreen] Verificando permisos básicos de ubicación...');
    
    // Solicitar SOLO permiso básico con diálogo de divulgación (como versión Azure)
    // El diálogo modal bloqueante "despierta" el sistema de renderizado
    try {
      final basicPermissionGranted = await LocationPermissionHelper.requestBasicLocationPermissionWithDisclosure(
        context,
        onPermissionGranted: () {
          debugPrint('✅ [SplashScreen] Permiso básico concedido. Navegando al LoginScreen...');
          // CRÍTICO: Usar addPostFrameCallback para asegurar que el frame se renderice
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && !_isNavigating) {
                _navigateToLogin();
              }
            });
          });
        },
      );
      
      // Si el usuario rechazó, la app ya se cerró
      if (!basicPermissionGranted && mounted) {
        debugPrint('⚠️ [SplashScreen] Permiso básico denegado. La app se cerrará.');
        return;
      }
      
      // Si aceptó pero el callback no se ejecutó, navegar como fallback
      if (basicPermissionGranted && !_isNavigating && mounted) {
        debugPrint('✅ [SplashScreen] Permiso básico concedido. Navegando al login como fallback...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && !_isNavigating) {
              _navigateToLogin();
            }
          });
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SplashScreen] Error al solicitar permisos básicos: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      // Si hay error, navegar al login de todas formas
      if (mounted && !_isNavigating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && !_isNavigating) {
              _navigateToLogin();
            }
          });
        });
      }
    }
  }
  
  /// Método auxiliar para navegar al LoginScreen de forma segura
  void _navigateToLogin() {
    // Verificar bandera PRIMERO para evitar doble navegación
    if (_isNavigating) {
      debugPrint('⚠️ [SplashScreen] Ya se está navegando, ignorando llamada duplicada');
      return;
    }
    
    if (!mounted) {
      debugPrint('⚠️ [SplashScreen] Widget no montado, no se puede navegar');
      return;
    }
    
    // Marcar que estamos navegando INMEDIATAMENTE para bloquear otros intentos
    _isNavigating = true;
    debugPrint('🚀 [SplashScreen] Iniciando navegación al LoginScreen...');
    
    // Ejecutar navegación directamente
    _executeNavigation();
  }
  
  /// Ejecuta la navegación de forma segura
  void _executeNavigation() {
    if (!mounted || !_isNavigating) {
      return;
    }
    
    try {
      debugPrint('🚀 [SplashScreen] Ejecutando navegación al LoginScreen...');
      
      // Usar Navigator local con pushReplacement (más simple que pushAndRemoveUntil)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) {
            debugPrint('🏗️ [SplashScreen] Construyendo LoginScreen...');
            return const LoginScreen(key: ValueKey('login_screen'));
          },
        ),
      );
      
      debugPrint('✅ [SplashScreen] Navegación ejecutada exitosamente');
    } catch (e, stackTrace) {
      debugPrint('❌ [SplashScreen] Error crítico al navegar: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      _isNavigating = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo grande (protagonista - tamaño responsivo)
              Image.asset(
                'assets/images/LogoCarga.png',
                height: (MediaQuery.of(context).size.height * 0.3).clamp(200.0, 240.0), // Responsivo con límites
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback si no carga el logo
                  return const Icon(
                    Icons.directions_car,
                    size: 240,
                    color: Color(0xFFEF1A2D), // Rojo corporativo
                  );
                },
              ),
              const SizedBox(height: 32),

              
              // Subtítulo descriptivo
              Text(
                'Seguridad Vehicular',
                style: TextStyle(
                  fontSize: 20, // Aumentado de 18 a 20
                  fontWeight: FontWeight.w400, // Aumentado de w300 a w400
                  color: Colors.grey[700], // Más oscuro
                  letterSpacing: 1.0, // Aumentado de 0.5 a 1.0
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
