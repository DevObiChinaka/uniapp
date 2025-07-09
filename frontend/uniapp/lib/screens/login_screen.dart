// login_screen.dart
import 'package:flutter/material.dart';
import 'package:uniapp/services/auth_service.dart';
import 'package:uniapp/screens/student_dashboard.dart';
import 'package:uniapp/screens/admin_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        Navigator.pushReplacementNamed(
          context,
          '/student_dashboard',
          arguments: args,
        );
        break;
      case 'admin':
        Navigator.pushReplacementNamed(
          context,
          '/admin_dashboard',
          arguments: args,
        );
        break;
      case 'lecturer':
        Navigator.pushReplacementNamed(
          context,
          '/lecturer_dashboard',
          arguments: args,
        );
        break;
      case 'security':
        Navigator.pushReplacementNamed(
          context,
          '/security_dashboard',
          arguments: args,
        );
        break;
      default:
        Navigator.pushReplacementNamed(context, '/login');
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
      await prefs.setBool('is_logged_in', true); // <-- Set after login

      // Navigate to appropriate dashboard based on role
      switch (data['role']) {
        case 'student':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => StudentDashboard(
                    firstName: data['first_name'],
                    lastName: data['last_name'],
                    universityId: data['university_id'],
                    token: data['access'],
                    role: data['role'],
                  ),
            ),
          );
          break;
        case 'admin':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => AdminDashboard(
                    firstName: data['first_name'],
                    lastName: data['last_name'],
                    universityId: data['university_id'],
                    token: data['access'],
                    role: data['role'],
                  ),
            ),
          );
          break;
        case 'lecturer':
          // Add LecturerDashboard here when implemented
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => Scaffold(
                    body: Center(child: Text('Lecturer Dashboard Coming Soon')),
                  ),
            ),
          );
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
    final isStudent = role == 'student';

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
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Color(0xFF6D5DF6),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[700],
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    DropdownButtonFormField<String>(
                      value: role,
                      items:
                          _roles
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.toUpperCase()),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => role = val!),
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: idOrUsernameController,
                      decoration: InputDecoration(
                        labelText:
                            role == 'student' ? 'University ID' : 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator:
                          (val) =>
                              val!.isEmpty ? 'This field is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      obscureText: true,
                      validator:
                          (val) =>
                              val!.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D5DF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        elevation: 8,
                      ),
                      onPressed: isLoading ? null : _handleLogin,
                      child:
                          isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'Login',
                                style: TextStyle(fontSize: 18),
                              ),
                    ),
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text('Don’t have an account? Register here'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
