import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/routes/app_router.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/services/core_services.dart';
import 'package:uniapp/services/face_service.dart';
import 'package:uniapp/screens/splash_screen.dart';

// Global key for navigator to show snackbars from non-widget contexts
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniApp());
}

Future<void> _setupFCM(CoreServices coreServices) async {
  final messaging = FirebaseMessaging.instance;

  // Request notification permissions
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // Get FCM token and register with backend
    final token = await messaging.getToken();
    if (token != null) {
      await coreServices.registerFcmToken(token);
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      coreServices.handlePushNotification(message);
    });
  }

  // Background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final coreServices = CoreServices();
  await coreServices.initialize();
  coreServices.handlePushNotification(message);
}

class UniApp extends StatefulWidget {
  const UniApp({super.key});

  @override
  State<UniApp> createState() => _UniAppState();
}

class _UniAppState extends State<UniApp> {
  bool _initialized = false;
  CoreServices? _coreServices;
  FaceService? _faceService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await Firebase.initializeApp();
    final coreServices = CoreServices();
    await coreServices.initialize();
    final faceService = FaceService();
    await faceService.initialize();
    await _setupFCM(coreServices);
    setState(() {
      _initialized = true;
      _coreServices = coreServices;
      _faceService = faceService;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Use the actual branded SplashScreen during initialization
      return MaterialApp(home: SplashScreen());
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (context) => AppProvider(
                coreServices: _coreServices!,
                faceService: _faceService!,
              ),
        ),
      ],
      child: AppLifecycleHandler(
        child: MaterialApp.router(
          routerConfig: AppRouter.router,
          title: 'UniApp',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[100],
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppLifecycleHandler extends StatefulWidget {
  final Widget child;
  const AppLifecycleHandler({required this.child, super.key});

  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await prefs.setInt('last_active', now);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
