import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/providers/auth_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'domain/models/user.dart';
import 'data/tracking_service.dart';
import 'core/services/alert_service.dart';
import 'core/services/navigation_service.dart';
import 'core/config/app_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
String? pendingDeviceIdFromNotification; // Almacenar deviceId de notificación cuando app está cerrada

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicio de rastreo y notificaciones
  await TrackingService().initializeNotifications();
  
  // Inicializar servicio de alertas
  await AlertService().initialize();
  
  // Verificar si la app se abrió desde una notificación (app cerrada)
  await _checkNotificationLaunch();
  
  // Configurar handler de notificaciones para deep linking
  await _configureNotificationHandling();
  
  // Solicitar permisos de notificaciones
  await _requestNotificationPermissions();
  
  runApp(const MyApp());
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
Future<void> _configureNotificationHandling() async {
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
void _navigateToMapFromNotification(String deviceId) {
  final deviceIdInt = int.tryParse(deviceId);
  
  // Asignar el ID del vehículo objetivo antes de navegar
  if (deviceIdInt != null) {
    AppConfig.targetVehicleId = deviceIdInt;
  }
  
  final navigator = NavigationService().navigatorKey.currentState;
  if (navigator != null) {
    // Navegar a la ruta '/monitor' con el deviceId como argumento
    navigator.pushNamed('/monitor', arguments: deviceId);
  }
}

/// Solicita permisos de notificaciones
Future<void> _requestNotificationPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
          primaryColor: Colors.red, // Rojo de HusatGps
          primarySwatch: Colors.red,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red, // Rojo
            brightness: Brightness.light,
            primary: Colors.red,
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/monitor': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final deviceId = args is String ? args : null;
            final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role ?? UserRole.client;
            return MapScreen(
              userRole: userRole,
              notificationDeviceId: deviceId != null ? int.tryParse(deviceId) : null,
            );
          },
        },
      ),
    );
  }
}
