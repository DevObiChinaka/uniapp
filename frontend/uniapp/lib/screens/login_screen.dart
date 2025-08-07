// login_screen.dart
import 'package:flutter/material.dart';
import 'package:uniapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart' as routes;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final idOrUsernameController = TextEditingController();
  final passwordController = TextEditingController();

  String role = 'student';
  final List<String> _roles = ['student', 'admin', 'lecturer', 'security'];
  bool isLoading = false;
  String error = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLoginEntry();
    });
  }

  Future<void> _handleLoginEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final timeout = prefs.getInt('biometric_timeout') ?? 0;
    final lastActive = prefs.getInt('last_active') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = prefs.getString('token');
    final role = prefs.getString('role');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    // Only allow dashboard shortcut if is_logged_in is true
    if (isLoggedIn &&
        timeout > 0 &&
        lastActive > 0 &&
        (now - lastActive) < timeout &&
        token != null &&
        role != null) {
      _goToDashboard(role, token, prefs);
      return;
    }
    // If session expired, reset is_logged_in
    if (isLoggedIn &&
        timeout > 0 &&
        lastActive > 0 &&
        (now - lastActive) >= timeout) {
      await prefs.setBool('is_logged_in', false);
    }
    // Otherwise, check permissions if needed (add here if required)
    // For now, do nothing (show login form)
  }

  void _goToDashboard(String role, String token, SharedPreferences prefs) {
    final args = {
      'firstName': prefs.getString('first_name') ?? '',
      'lastName': prefs.getString('last_name') ?? '',
      'universityId': prefs.getString('university_id') ?? '',
      'token': token,
      'role': role,
    };
    switch (role) {
      case 'student':
        context.go(routes.AppRoutes.studentDashboard, extra: args);
        break;
      case 'admin':
        context.go(routes.AppRoutes.adminDashboard, extra: args);
        break;
      case 'lecturer':
        context.go(routes.AppRoutes.lecturerDashboard, extra: args);
        break;
      case 'security':
        context.go(routes.AppRoutes.securityDashboard, extra: args);
        break;
      default:
        context.go(routes.AppRoutes.login);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = '';
    });

    final response = await AuthService().login(
      usernameOrId: idOrUsernameController.text.trim(),
      password: passwordController.text,
      role: role,
    );

    setState(() => isLoading = false);

    if (response['success']) {
      final data = response['data'];

      // Save credentials in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['access']);
      await prefs.setString('refresh', data['refresh']);
      await prefs.setString('role', data['role']);
      await prefs.setString('university_id', data['university_id'] ?? '');
      await prefs.setString('first_name', data['first_name'] ?? '');
      await prefs.setString('last_name', data['last_name'] ?? '');
      await prefs.setString('username', data['username'] ?? '');
      await prefs.setString('user_id', data['id']?.toString() ?? '');
      await prefs.setBool('is_logged_in', true); // <-- Set after login

      // Navigate to appropriate dashboard based on role
      final args = {
        'firstName': data['first_name'],
        'lastName': data['last_name'],
        'universityId': data['university_id'],
        'token': data['access'],
        'role': data['role'],
      };

      switch (data['role']) {
        case 'student':
          context.go(routes.AppRoutes.studentDashboard, extra: args);
          break;
        case 'admin':
          context.go(routes.AppRoutes.adminDashboard, extra: args);
          break;
        case 'lecturer':
          context.go(routes.AppRoutes.lecturerDashboard, extra: args);
          break;
        case 'security':
          context.go(routes.AppRoutes.securityDashboard, extra: args);
          break;
        default:
          setState(() {
            error = 'Unsupported role: ${data['role']}';
          });
      }
    } else {
      setState(() {
        error = response['message'] ?? 'Login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: 60),

                  // Logo and Welcome Section
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'SALMS',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Smart Attendance & Leave Management',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Login Form Container
                  Container(
                    padding: EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sign in to your account to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 32),

                          // Role Selection
                          Text(
                            'Select Role',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: role,
                              items:
                                  _roles
                                      .map(
                                        (r) => DropdownMenuItem(
                                          value: r,
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getRoleIcon(r),
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                _getRoleDisplayName(r),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) => setState(() => role = val!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Username/ID Field
                          Text(
                            role == 'student' ? 'University ID' : 'Username',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: idOrUsernameController,
                              decoration: InputDecoration(
                                hintText:
                                    role == 'student'
                                        ? 'Enter your university ID'
                                        : 'Enter your username',
                                prefixIcon: Icon(
                                  role == 'student'
                                      ? Icons.badge_outlined
                                      : Icons.person_outline,
                                  color: Theme.of(context).primaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator:
                                  (val) =>
                                      val!.isEmpty
                                          ? 'This field is required'
                                          : null,
                            ),
                          ),

                          SizedBox(height: 20),

                          // Password Field
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Theme.of(context).primaryColor,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator:
                                  (val) =>
                                      val!.length < 6
                                          ? 'Password must be at least 6 characters'
                                          : null,
                            ),
                          ),

                          SizedBox(height: 32),

                          // Login Button
                          Container(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.3),
                              ),
                              onPressed: isLoading ? null : _handleLogin,
                              child:
                                  isLoading
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Signing In...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                      : Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),

                          // Error Message
                          if (error.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          SizedBox(height: 24),

                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.go(routes.AppRoutes.register);
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Register here',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'student':
        return Icons.school_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'lecturer':
        return Icons.person_outline;
      case 'security':
        return Icons.security_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'student':
        return 'Student';
      case 'admin':
        return 'Administrator';
      case 'lecturer':
        return 'Lecturer';
      case 'security':
        return 'Security Personnel';
      default:
        return role.toUpperCase();
    }
  }
}
