import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:uniapp/services/biometric_service.dart';
import 'package:uniapp/screens/app_constants.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndBiometric();
    });
  }

  Future<void> _checkPermissionsAndBiometric() async {
    // Add permission checks here if needed (biometric, etc.)
    // For now, just call _checkBiometric
    await _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final prefs = await SharedPreferences.getInstance();

    // Debug: Print stored preferences
    print('--- SharedPreferences ---');
    for (var key in prefs.getKeys()) {
      print('$key: ${prefs.get(key)}');
    }

    final isEnabled = await biometricService.isBiometricEnabled();
    final refreshToken = prefs.getString('refresh');
    print('Biometric enabled: $isEnabled');
    print('Refresh token: $refreshToken');

    if (!isEnabled || refreshToken == null || refreshToken.isEmpty) {
      print('Biometric login disabled or no refresh token found.');
      _navigateToLogin();
      return;
    }

    final success = await biometricService.authenticate(
      "Log in with fingerprint",
    );
    print('Biometric authentication success: $success');

    if (success) {
      final newAccessToken = await _getNewAccessToken(refreshToken);
      if (newAccessToken != null) {
        // Save last active time (seconds since epoch)
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await prefs.setInt('last_active', now);
        await prefs.setBool(
          'is_logged_in',
          true,
        ); // <-- Set after biometric login
        await _fetchUserProfileAndNavigate(newAccessToken);
      } else {
        _showSnackBar('Session expired. Please log in again.');
        _navigateToLogin();
      }
    } else {
      _showSnackBar('Biometric authentication failed');
    }
  }

  Future<String?> _getNewAccessToken(String refreshToken) async {
    try {
      print('Requesting new access token using refresh token...');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      print('Token refresh response: ${response.statusCode}');
      print('Token refresh body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', newAccessToken);
        print('New access token saved.');

        return newAccessToken;
      } else {
        print('Failed to refresh token: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Token refresh error: $e');
      return null;
    }
  }

  Future<void> _fetchUserProfileAndNavigate(String token) async {
    try {
      print('Fetching user profile with access token...');
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Profile fetch response: ${response.statusCode}');
      print('Profile fetch body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        if (data['first_name'] != null)
          await prefs.setString('first_name', data['first_name']);
        if (data['last_name'] != null)
          await prefs.setString('last_name', data['last_name']);
        if (data['role'] != null) await prefs.setString('role', data['role']);

        if (data['role'] == 'admin') {
          if (data['username'] != null)
            await prefs.setString('username', data['username']);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/admin_dashboard',
            arguments: {'username': data['username'] ?? '', 'token': token},
          );
        } else {
          if (data['university_id'] != null)
            await prefs.setString('university_id', data['university_id']);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/home_screen',
            arguments: {
              'firstName': data['first_name'] ?? '',
              'lastName': data['last_name'] ?? '',
              'universityId': data['university_id'] ?? '',
              'token': token,
              'role': data['role'] ?? '',
            },
          );
        }
      } else {
        _showSnackBar('Session expired. Please log in again.');
        _navigateToLogin();
      }
    } catch (e) {
      print('Fetch profile error: $e');
      _showSnackBar('Error occurred. Please try again.');
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    print('Redirecting to manual login...');
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "Use Fingerprint to Login",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text("Try Again"),
                onPressed: _checkBiometric,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _navigateToLogin,
                child: const Text("Login with Credentials Instead"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
