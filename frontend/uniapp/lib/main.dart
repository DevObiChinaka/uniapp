import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/routes/app_router.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/services/core_services.dart';
import 'package:uniapp/services/face_service.dart';

// Global key for navigator to show snackbars from non-widget contexts
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize core services (lightweight initialization only)
  final coreServices = CoreServices();
  
  // Initialize Face Service (lightweight initialization only)
  final faceService = FaceService();

  // Defer heavy initialization to after the app starts
  _deferHeavyInitialization(coreServices, faceService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (context) => AppProvider(
                coreServices: coreServices,
                faceService: faceService,
              ),
        ),
      ],
      child: const UniApp(),
    ),
  );
}

// Perform heavy initialization in the background after app startup
Future<void> _deferHeavyInitialization(CoreServices coreServices, FaceService faceService) async {
  // Use a microtask to defer execution until after the current frame
  Future.microtask(() async {
    try {
      // Initialize services in the background
      await Future.wait([
        coreServices.initialize(),
        // Don't initialize face service until it's actually needed
        // faceService.initialize(),
      ]);
      debugPrint('Background initialization completed');
    } catch (e) {
      debugPrint('Background initialization error: $e');
    }
  });
}

class UniApp extends StatelessWidget {
  const UniApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Defer AppProvider initialization to avoid blocking the UI
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    Future.microtask(() => appProvider.initialize());

    return AppLifecycleHandler(
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

// SplashScreen has been moved to its own file

// SplashScreen and BiometricLoginScreen have been moved to their own files
