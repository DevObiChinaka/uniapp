import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/login_screen.dart';
import 'package:uniapp/screens/register_screen.dart';
import 'package:uniapp/screens/edit_profile_screen.dart';
import 'package:uniapp/services/biometric_service.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/services/core_services.dart';
import 'package:uniapp/services/face_service.dart';
import 'package:uniapp/screens/student_dashboard.dart';
import 'package:uniapp/screens/lecturer_dashboard.dart';
import 'package:uniapp/screens/security_dashboard.dart';
import 'package:uniapp/screens/admin_dashboard.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final coreServices = CoreServices();
  await coreServices.initialize();
  final faceService = FaceService();
  await faceService.initialize();
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
    return MaterialApp(
      title: 'Smart Attendance & Leave Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF6D5DF6),
          secondary: Color(0xFFB07DFB),
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF6D5DF6),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.biometricLogin: (context) => const BiometricLoginScreen(),
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
    );
  }
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
    _routeAfterSplash();
  }

  Future<void> _routeAfterSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (biometricEnabled) {
      Navigator.pushReplacementNamed(context, AppRoutes.biometricLogin);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Morph card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: Color(0xFF6D5DF6),
                ),
              ),
              const SizedBox(height: 32),
              // App title
              Text(
                'Smart Attendance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D5DF6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'and Leave Management',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB07DFB),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              // Animated progress
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D5DF6)),
                strokeWidth: 4,
              ),
            ],
          ),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D5DF6), Color(0xFFB07DFB), Color(0xFFF3F3F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Morph card for biometric icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 80,
                  color:
                      _isAuthenticating ? Colors.blue : const Color(0xFF6D5DF6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Biometric Login',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple[700],
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              if (_isAuthenticating) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D5DF6)),
                  strokeWidth: 4,
                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D5DF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    elevation: 8,
                  ),
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
  static const String login = '/login';
  static const String register = '/register';
  static const String biometricLogin = '/biometric-login';
  static const String editProfile = '/edit-profile';
  static const String studentDashboard = '/student-dashboard';
  static const String lecturerDashboard = '/lecturer-dashboard';
  static const String securityDashboard = '/security-dashboard';
  static const String adminDashboard = '/admin-dashboard';
}
