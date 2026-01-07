import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'data/tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicio de rastreo y notificaciones
  await TrackingService().initializeNotifications();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'HusatGps',
        debugShowCheckedModeBanner: false,
        // Configuración de localizaciones para soportar español e inglés
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'), // Español
          Locale('en', 'US'), // Inglés
        ],
        locale: const Locale('es', 'ES'), // Idioma por defecto: español
        theme: ThemeData(
          primaryColor: Colors.red, // Rojo de HusatGps
          primarySwatch: Colors.red,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red, // Rojo
            brightness: Brightness.light,
            primary: Colors.red,
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
