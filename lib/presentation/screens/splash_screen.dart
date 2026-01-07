import 'package:flutter/material.dart';
import 'login_screen.dart';

/// Pantalla de carga inicial con logo y nombre de la aplicación.
/// 
/// Muestra:
/// - Logo grande (180-200px de altura)
/// - Texto "MiHusatGPS" debajo del logo
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
    
    // Navegar al Login después de 2.5 segundos
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });
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
              // Logo grande (protagonista - tamaño aumentado)
              Image.asset(
                'assets/images/logo.png',
                height: 240, // Aumentado de 200 a 240 para mayor protagonismo
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback si no carga el logo
                  return Image.asset(
                    'assets/logo.png',
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/logo.empresa.png',
                        height: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.directions_car,
                            size: 240,
                            color: Color(0xFFD32F2F), // Rojo corporativo
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // Nombre de la marca "MiHusatGPS"
              const Text(
                'MiHusatGPS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F), // Rojo corporativo
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtítulo descriptivo
              Text(
                'Rastreo Satelital en Tiempo Real',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300, // Fuente delgada
                  color: Colors.grey.shade600, // Gris claro
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
