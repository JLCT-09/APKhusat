import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/supervision_filter_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/main_layout.dart';
import 'core/services/alert_service.dart';
import 'core/services/navigation_service.dart';
import 'core/config/app_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
String? pendingDeviceIdFromNotification; // Almacenar deviceId de notificación cuando app está cerrada

/// OPTIMIZACIÓN: main() refactorizado para no bloquear el inicio de la app
/// Las inicializaciones pesadas se ejecutan en paralelo sin esperar (await) antes de runApp
/// Esto elimina el bloqueo de pantalla blanca (FrameInsert fail)
void main() async {
  // CRÍTICO: Primera línea debe ser ensureInitialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // OPTIMIZACIÓN: Ejecutar inicializaciones pesadas en paralelo sin esperar (await) antes de runApp
  // Esto permite que la app inicie inmediatamente mientras los servicios se inicializan en segundo plano
  unawaited(_initAsyncServices());
  
  // CRÍTICO: runApp debe ejecutarse INMEDIATAMENTE, sin esperar servicios pesados
  // Esto elimina el bloqueo de pantalla blanca durante la inicialización
  runApp(const MyApp());
}

/// Agrupa todas las inicializaciones pesadas de servicios
/// Se ejecuta en paralelo sin bloquear el inicio de la app
/// DIAGNÓSTICO: Comentado temporalmente para diagnosticar pantalla blanca
Future<void> _initAsyncServices() async {
  try {
    // DIAGNÓSTICO: Comentado temporalmente para diagnosticar pantalla blanca
    // Inicializar servicio de alertas (con manejo de errores)
    // try {
    //   await AlertService().initialize();
    //   debugPrint('✅ [main.dart] AlertService inicializado');
    // } catch (e) {
    //   debugPrint('⚠️ [main.dart] Error al inicializar AlertService (no crítico): $e');
    // }
    
    // DIAGNÓSTICO: Comentado temporalmente para diagnosticar pantalla blanca
    // Verificar si la app se abrió desde una notificación (app cerrada)
    // CRÍTICO: Esto debe ejecutarse antes de que la app inicie para capturar el deviceId
    // try {
    //   await _checkNotificationLaunch();
    //   debugPrint('✅ [main.dart] Verificación de notificación de lanzamiento completada');
    // } catch (e) {
    //   debugPrint('⚠️ [main.dart] Error al verificar notificación de lanzamiento: $e');
    // }
    
    // NOTA: _configureNotificationHandling se ejecutará desde SplashScreen
    // para asegurar que la app esté completamente montada antes de configurar notificaciones
    debugPrint('🔍 [main.dart] DIAGNÓSTICO: Servicios comentados temporalmente');
  } catch (e) {
    // Error crítico en inicialización - log pero continuar
    debugPrint('❌ [main.dart] Error crítico en inicialización: $e');
    debugPrint('   La app continuará funcionando sin estos servicios');
  }
}

/// Verifica si la app se abrió desde una notificación (cuando estaba cerrada)
Future<void> _checkNotificationLaunch() async {
  final details = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp ?? false) {
    final payload = details!.notificationResponse?.payload;
    if (payload != null) {
      // Payload es solo el deviceId como String
      pendingDeviceIdFromNotification = payload;
    }
  }
}

/// Configura el manejo de notificaciones para deep linking
/// OPTIMIZACIÓN: Esta función se llama desde SplashScreen para asegurar que la app esté completamente montada
/// antes de configurar notificaciones. Esto evita bloqueos durante la inicialización.
/// PÚBLICA: Necesaria para ser llamada desde SplashScreen
Future<void> configureNotificationHandling() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Manejar tap en notificación para deep linking (app en segundo plano)
      if (response.payload != null) {
        // Payload es solo el deviceId como String
        final deviceId = response.payload!;
        _navigateToMapFromNotification(deviceId);
      }
    },
  );
}

/// Navega al mapa desde una notificación (usando GlobalKey)
/// Si el usuario no está autenticado, guarda el deviceId para navegar después del login
/// 
/// NOTA: Esta función se llama cuando la app está en segundo plano o se abre desde notificación.
/// Si la app está en segundo plano y el usuario ya está autenticado, navegará directamente.
/// Si la app se abre desde notificación sin autenticación, guardará el deviceId para después del login.
void _navigateToMapFromNotification(String deviceId) {
  final deviceIdInt = int.tryParse(deviceId);
  
  // Asignar el ID del vehículo objetivo antes de navegar
  if (deviceIdInt != null) {
    AppConfig.targetVehicleId = deviceIdInt;
  }
  
  final navigator = NavigationService().navigatorKey.currentState;
  if (navigator == null) {
    debugPrint('⚠️ [main.dart] Navigator no disponible, guardando deviceId para después del login');
    // Guardar deviceId para navegar después del login
    pendingDeviceIdFromNotification = deviceId;
    return;
  }
  
  // Intentar navegar directamente (si el usuario ya está autenticado)
  // Si falla o estamos en LoginScreen, el deviceId ya está guardado en pendingDeviceIdFromNotification
  // y el LoginScreen lo manejará después del login exitoso
  try {
    debugPrint('📱 [main.dart] Intentando navegar al monitor con deviceId: $deviceId');
    navigator.pushNamed('/monitor', arguments: deviceId);
  } catch (e) {
    // Si falla la navegación (por ejemplo, estamos en LoginScreen), guardar para después
    debugPrint('⚠️ [main.dart] Error al navegar, guardando deviceId para después del login: $e');
    pendingDeviceIdFromNotification = deviceId;
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupervisionFilterProvider()),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService().navigatorKey,
        title: 'MiHusatGps',
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
          primaryColor: const Color(0xFFEF1A2D), // Color corporativo HusatGps
          scaffoldBackgroundColor: Colors.white, // CRÍTICO: Fondo blanco explícito
          primarySwatch: MaterialColor(
            0xFFEF1A2D,
            <int, Color>{
              50: const Color(0xFFEF1A2D).withOpacity(0.1),
              100: const Color(0xFFEF1A2D).withOpacity(0.2),
              200: const Color(0xFFEF1A2D).withOpacity(0.3),
              300: const Color(0xFFEF1A2D).withOpacity(0.4),
              400: const Color(0xFFEF1A2D).withOpacity(0.5),
              500: const Color(0xFFEF1A2D).withOpacity(0.6),
              600: const Color(0xFFEF1A2D).withOpacity(0.7),
              700: const Color(0xFFEF1A2D).withOpacity(0.8),
              800: const Color(0xFFEF1A2D).withOpacity(0.9),
              900: const Color(0xFFEF1A2D),
            },
          ),
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEF1A2D), // Color corporativo
            brightness: Brightness.light,
            primary: const Color(0xFFEF1A2D),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/monitor': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final deviceId = args is String ? int.tryParse(args) : null;
            // Navegar a MainLayout con índice 0 (Monitor) y deviceId si existe
            return MainLayout(
              initialIndex: 0,
              notificationDeviceId: deviceId,
            );
          },
        },
      ),
    );
  }
}
