import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/location_permission_helper.dart';
import '../../main.dart' show pendingDeviceIdFromNotification;
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _pendingDeviceIdFromNotification; // ID pendiente de notificación

  @override
  void initState() {
    super.initState();
    // Verificar si hay un ID pendiente proveniente de las notificaciones
    _pendingDeviceIdFromNotification = pendingDeviceIdFromNotification;
    // Limpiar la variable global después de leerla
    pendingDeviceIdFromNotification = null;
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsuario(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su usuario';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    return null;
  }
  
  /// Solicita permisos de ubicación en segundo plano después del login exitoso
  /// CRÍTICO: Se ejecuta solo después de que el login sea exitoso y el usuario esté dentro de la app
  /// Esto evita bloqueos y pantallas en blanco durante el SplashScreen
  void _requestBackgroundLocationPermission() {
    debugPrint('📱 [LoginScreen] Preparando solicitud de permisos de segundo plano después del login...');
    // CRÍTICO: Delay más largo para asegurar que el usuario ya esté dentro del MainLayout
    // Esto evita que el diálogo de segundo plano interfiera con la navegación
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) {
        debugPrint('⚠️ [LoginScreen] Widget desmontado, cancelando solicitud de segundo plano');
        return;
      }
      
      try {
        final hasBasic = await LocationPermissionHelper.hasBasicLocationPermission();
        if (!hasBasic) {
          debugPrint('⚠️ [LoginScreen] Permiso básico no concedido, no se puede solicitar segundo plano');
          return;
        }
        
        // Verificar si ya tiene permiso de segundo plano
        final hasBackground = await LocationPermissionHelper.hasAllLocationPermissions();
        if (hasBackground) {
          debugPrint('✅ [LoginScreen] Permisos de segundo plano ya concedidos');
          return;
        }
        
        // CRÍTICO: Solicitar permiso de segundo plano solo cuando el usuario ya está dentro de la app
        debugPrint('📱 [LoginScreen] Solicitando permiso de ubicación en segundo plano (después del login)...');
        final backgroundStatus = await LocationPermissionHelper.requestBackgroundLocationPermission();
        if (backgroundStatus) {
          debugPrint('✅ [LoginScreen] Permiso de segundo plano concedido');
        } else {
          debugPrint('⚠️ [LoginScreen] Permiso de segundo plano denegado');
        }
      } catch (e) {
        debugPrint('❌ [LoginScreen] Error al solicitar permisos de segundo plano: $e');
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // OPTIMIZACIÓN: Ocultar el teclado ANTES de hacer login para evitar transición entrecortada
      FocusScope.of(context).unfocus();
      
      // Esperar un momento para que el teclado se oculte completamente antes de navegar
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Usar credenciales por defecto según especificaciones: nombreUsuario "Jherson", clave "123456"
      final nombreUsuario = _usuarioController.text.trim().isEmpty 
          ? 'Jherson' 
          : _usuarioController.text.trim();
      final clave = _passwordController.text.isEmpty 
          ? '123456' 
          : _passwordController.text;
      
      final success = await authProvider.login(nombreUsuario, clave);

      if (success && mounted) {
        final user = authProvider.user;
        if (user != null) {
          // OPTIMIZACIÓN: Esperar un frame adicional para asegurar que el teclado se haya ocultado completamente
          await Future.delayed(const Duration(milliseconds: 50));
          
          if (!mounted) return;
          
          // DIAGNÓSTICO: Comentado temporalmente para diagnosticar pantalla blanca
          // Solicitar permisos de segundo plano después del login (sin bloquear navegación)
          // _requestBackgroundLocationPermission();
          
          // OPTIMIZACIÓN: Usar transición suave con PageRouteBuilder para mejor fluidez
          // Si hay deviceId pendiente de notificación, navegar al Monitor con ese ID
          if (_pendingDeviceIdFromNotification != null) {
            final deviceId = _pendingDeviceIdFromNotification;
            _pendingDeviceIdFromNotification = null; // Limpiar después de usar
            
            // Navegar al Monitor usando la ruta nombrada con el deviceId como argumento
            Navigator.of(context).pushReplacementNamed(
              '/monitor',
              arguments: deviceId,
            );
          } else {
            // OPTIMIZACIÓN: Transición suave con fade para mejor percepción de velocidad
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const MainLayout(initialIndex: 0),
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
              ),
            );
          }
        }
      } else if (mounted) {
        // Mostrar error de comunicación con código
        String mensajeError = authProvider.errorMessage ?? 'Credenciales Incorrectas';
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

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [LoginScreen] Build ejecutándose - Context: ${context.hashCode}');
    final size = MediaQuery.of(context).size;
    debugPrint('🎨 [LoginScreen] MediaQuery size: ${size.width}x${size.height}');
    
    return Scaffold(
      key: const ValueKey('login_scaffold'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                // Logo de la empresa
                Image.asset(
                  'assets/images/LogoLogin.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.directions_car,
                      size: 60,
                      color: Color(0xFFEF1A2D),
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // Campo de Usuario
                TextFormField(
                  controller: _usuarioController,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'Ingrese su usuario',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: _validateUsuario,
                ),
                const SizedBox(height: 24),
                
                // Campo de Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingrese su contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 40),
                
                // Botón de iniciar sesión
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: const Color(0xFFEF1A2D),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFFEF1A2D).withOpacity(0.3),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
