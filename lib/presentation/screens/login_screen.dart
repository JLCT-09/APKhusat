import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../main.dart' show pendingDeviceIdFromNotification;
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
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
            // Si no hay ID pendiente, navegar normalmente al MapScreen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MapScreen(
                  userRole: user.role,
                ),
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Primero: Logo de la empresa
                  Image.asset(
                    'assets/logo.empresa.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback rojo temporal si no carga el logo
                      return const Icon(
                        Icons.directions_car,
                        size: 80,
                        color: Colors.red, // Rojo temporal
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Segundo: Título
                  const Text(
                    'HusatGps',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD32F2F), // Rojo corporativo
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Tercero: Campo de Usuario
                  TextFormField(
                    controller: _usuarioController,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      hintText: 'Ingrese su usuario',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validateUsuario,
                  ),
                  const SizedBox(height: 20),
                  
                  // Tercero: Campo de Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      hintText: 'Ingrese su contraseña',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 32),
                  
                  // Cuarto: Botón de iniciar sesión
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFFD32F2F), // Rojo corporativo
                            foregroundColor: Colors.white,
                          ),
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
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
