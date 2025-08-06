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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimations();
      _routeAfterSplash();
    });
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
              Theme.of(context).primaryColor.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _fadeController,
              _scaleController,
              _slideController,
            ]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo Container with Scale Animation
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(
                                    Icons.school_outlined,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // SALMS Title with Slide Animation
                            SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'SALMS',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 3,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Smart Attendance & Leave Management',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Section with Loading
                    Expanded(
                      flex: 1,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Modern Loading Indicator
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 3,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Loading Text
                            Text(
                              'Initializing...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Security Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'University-Grade Security',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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

class _BiometricLoginScreenState extends State<BiometricLoginScreen>
    with TickerProviderStateMixin {
  bool _isAuthenticating = false;
  String _error = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
    _tryBiometricLogin();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
              Theme.of(context).primaryColor.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Biometric Icon with Pulse Animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale:
                                _isAuthenticating ? _pulseAnimation.value : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.fingerprint,
                                  size: 80,
                                  color:
                                      _isAuthenticating
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Title
                      Text(
                        'Biometric Authentication',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Secure login with your biometrics',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Section
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isAuthenticating) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Authenticating...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        if (_error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[300],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Try Again Button
                        Container(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            onPressed: _tryBiometricLogin,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Use Password Button
                        TextButton(
                          onPressed: () {
                            context.go(routes.AppRoutes.login);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Use Password Instead',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
