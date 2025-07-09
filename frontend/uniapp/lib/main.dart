import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/login_screen.dart';
import 'package:uniapp/screens/register_screen.dart';
import 'package:uniapp/screens/edit_profile_screen.dart';
// import 'package:uniapp/screens/onboarding_screen.dart';
import 'package:uniapp/services/biometric_service.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/services/core_services.dart';
import 'package:uniapp/services/face_service.dart';
import 'package:uniapp/screens/student_dashboard.dart';
import 'package:uniapp/screens/lecturer_dashboard.dart';
import 'package:uniapp/screens/security_dashboard.dart';
import 'package:uniapp/screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize core services
  final coreServices = CoreServices();
  await coreServices.initialize();

  // Initialize Face Service
  final faceService = FaceService();
  await faceService.initialize();

  // Setup FCM
  await _setupFCM(coreServices);

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

class UniApp extends StatelessWidget {
  const UniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleHandler(
      child: MaterialApp(
        title: 'Smart Attendance & Leave Management',
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
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (context) => const SplashScreen(),
          // AppRoutes.onboarding: (context) => const OnboardingScreen(), // Removed
          AppRoutes.login: (context) => const LoginScreen(),
          AppRoutes.register: (context) => const RegisterScreen(),
          AppRoutes.editProfile: (context) => const EditProfileScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle dashboard routes with arguments
          if (settings.name == AppRoutes.studentDashboard) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder:
                  (_) => StudentDashboard(
                    firstName: args?['firstName'] ?? '',
                    lastName: args?['lastName'] ?? '',
                    universityId: args?['universityId'] ?? '',
                    token: args?['token'] ?? '',
                    role: args?['role'] ?? AppConstants.studentRole,
                  ),
            );
          } else if (settings.name == AppRoutes.lecturerDashboard) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder:
                  (_) => LecturerDashboard(
                    firstName: args?['firstName'] ?? '',
                    lastName: args?['lastName'] ?? '',
                    token: args?['token'] ?? '',
                    role: args?['role'] ?? AppConstants.lecturerRole,
                  ),
            );
          } else if (settings.name == AppRoutes.securityDashboard) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder:
                  (_) => SecurityDashboard(
                    token: args?['token'] ?? '',
                    role: args?['role'] ?? AppConstants.securityRole,
                  ),
            );
          } else if (settings.name == AppRoutes.adminDashboard) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder:
                  (_) => AdminDashboard(
                    firstName: args?['firstName'] ?? '',
                    lastName: args?['lastName'] ?? '',
                    universityId: args?['universityId'] ?? '',
                    token: args?['token'] ?? '',
                    role: args?['role'] ?? AppConstants.adminRole,
                  ),
            );
          }

          return null;
        },
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final hasUserId = prefs.containsKey('university_id');
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Small splash delay

    if (!mounted) return;

    // If user is already logged in, go to their dashboard
    if (token != null && role != null) {
      final args = {
        'firstName': prefs.getString('first_name') ?? '',
        'lastName': prefs.getString('last_name') ?? '',
        'universityId': prefs.getString('university_id') ?? '',
        'token': token,
        'role': role,
      };

      switch (role) {
        case AppConstants.studentRole:
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.studentDashboard,
            arguments: args,
          );
          break;
        case AppConstants.lecturerRole:
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.lecturerDashboard,
            arguments: args,
          );
          break;
        case AppConstants.securityRole:
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.securityDashboard,
            arguments: args,
          );
          break;
        case AppConstants.adminRole:
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.adminDashboard,
            arguments: args,
          );
          break;
        default:
          // If role is not recognized, go to login
          Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
    // If biometric is enabled and user has university ID, go to biometric login
    else if (biometricEnabled && hasUserId) {
      Navigator.pushReplacementNamed(context, AppRoutes.biometricLogin);
    }
    // Check if role is selected but not logged in
    else if (prefs.containsKey('selected_role')) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
    // Otherwise, go to register
    else {
      Navigator.pushReplacementNamed(context, AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, size: 80, color: Colors.deepPurple),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  bool _isAuthenticating = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tryBiometricLogin();
  }

  Future<void> _tryBiometricLogin() async {
    setState(() {
      _isAuthenticating = true;
      _error = '';
    });

    try {
      await checkBiometricLogin(context);
    } catch (e) {
      setState(() {
        _error = 'Biometric login failed. Please try again.';
      });
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            if (_isAuthenticating) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Authenticating...'),
            ] else ...[
              Text(
                _error.isNotEmpty ? _error : 'Use biometrics to login',
                style: TextStyle(
                  color: _error.isNotEmpty ? Colors.red : Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _tryBiometricLogin,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                child: const Text('Use Password Instead'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> checkBiometricLogin(BuildContext context) async {
  final biometricService = BiometricService();
  final prefs = await SharedPreferences.getInstance();

  final biometricEnabled = await biometricService.isBiometricEnabled();
  final universityId = prefs.getString('university_id');

  if (biometricEnabled && universityId != null) {
    final authenticated = await biometricService.authenticate(
      'Login with biometrics',
    );

    if (authenticated) {
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.baseUrl}/api/biometric-login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'university_id': universityId}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['data'];
          final role = data['role'];

          // Store updated values
          await prefs.setString('token', data['token']);
          await prefs.setString('role', role);
          await prefs.setString('first_name', data['first_name']);
          await prefs.setString('last_name', data['last_name']);
          await prefs.setString('university_id', data['university_id']);

          // Navigate to appropriate dashboard
          final args = {
            'firstName': data['first_name'],
            'lastName': data['last_name'],
            'universityId': data['university_id'],
            'token': data['token'],
            'role': role,
          };

          switch (role) {
            case AppConstants.studentRole:
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.studentDashboard,
                arguments: args,
              );
              break;
            case AppConstants.lecturerRole:
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.lecturerDashboard,
                arguments: args,
              );
              break;
            case AppConstants.securityRole:
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.securityDashboard,
                arguments: args,
              );
              break;
            case AppConstants.adminRole:
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.adminDashboard,
                arguments: args,
              );
              break;
            default:
              Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        } else {
          throw Exception('Biometric login failed: ${response.body}');
        }
      } catch (e) {
        throw Exception('Network error: $e');
      }
    } else {
      throw Exception('Authentication failed');
    }
  } else {
    throw Exception('Biometrics not enabled');
  }
}

// AppRoutes class should be defined if not already
class AppRoutes {
  static const String splash = '/';
  // static const String onboarding = '/onboarding'; // Removed
  static const String login = '/login';
  static const String register = '/register';
  static const String biometricLogin = '/biometric-login';
  static const String editProfile = '/edit-profile';
  static const String studentDashboard = '/student-dashboard';
  static const String lecturerDashboard = '/lecturer-dashboard';
  static const String securityDashboard = '/security-dashboard';
  static const String adminDashboard = '/admin-dashboard';
}
