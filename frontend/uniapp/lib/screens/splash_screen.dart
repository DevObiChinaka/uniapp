import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../routes/app_routes.dart' as routes;
import '../services/biometric_service.dart';
import 'app_constants.dart';

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
      context.go(routes.AppRoutes.biometricLogin);
    } else {
      context.go(routes.AppRoutes.login);
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
                child: const Icon(
                  Icons.fact_check_rounded, // Modern attendance/checklist icon
                  size: 80,
                  color: Color(0xFF6D5DF6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SALMS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D5DF6),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Color(0xFFB07DFB),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Smart Attendance & Leave Management System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB07DFB),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 36),
              // Animated progress
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D5DF6)),
                strokeWidth: 4,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified_user, color: Color(0xFFB07DFB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'University-Grade Security',
                    style: TextStyle(
                      color: Color(0xFF6D5DF6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
                    context.go(routes.AppRoutes.login);
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
              context.go(routes.AppRoutes.studentDashboard, extra: args);
              break;
            case AppConstants.lecturerRole:
              context.go(routes.AppRoutes.lecturerDashboard, extra: args);
              break;
            case AppConstants.securityRole:
              context.go(routes.AppRoutes.securityDashboard, extra: args);
              break;
            case AppConstants.adminRole:
              context.go(routes.AppRoutes.adminDashboard, extra: args);
              break;
            default:
              context.go(routes.AppRoutes.login);
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
