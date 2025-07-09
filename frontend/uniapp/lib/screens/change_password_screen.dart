import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uniapp/screens/app_constants.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isVerified = false;
  bool isLoading = false;
  String error = '';
  String? token;

  @override
  void initState() {
    super.initState();
    _loadTokenAndShowVerifyDialog();
  }

  Future<void> _loadTokenAndShowVerifyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null) {
      setState(() => error = 'Missing token. Please log in again.');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _showVerifyDialog());
  }

  Future<void> _showVerifyDialog() async {
    final TextEditingController passwordController = TextEditingController();
    bool verifying = false;
    String verifyError = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: const Text('Verify Password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                      ),
                    ),
                    if (verifyError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          verifyError,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        verifying
                            ? null
                            : () async {
                              setModalState(() => verifying = true);
                              final verified = await _verifyCurrentPassword(
                                passwordController.text.trim(),
                              );
                              setModalState(() => verifying = false);
                              if (verified) {
                                setState(() => isVerified = true);
                                Navigator.pop(context);
                              } else {
                                setModalState(
                                  () => verifyError = 'Incorrect password',
                                );
                              }
                            },
                    child:
                        verifying
                            ? const CircularProgressIndicator()
                            : const Text('Verify'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<bool> _verifyCurrentPassword(String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/verify-password/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': password}),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/change-password/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'new_password': newPasswordController.text.trim()}),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['detail'] ?? 'Failed to change password.';
        });
      }
    } catch (_) {
      setState(() {
        isLoading = false;
        error = 'An error occurred. Please try again.';
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Must include a special character';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : isVerified
              ? Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                        ),
                        validator: _validatePassword,
                      ),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please confirm new password';
                          }
                          if (val != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _changePassword,
                        child: const Text('Change Password'),
                      ),
                      if (error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              : const Center(child: Text("Verifying...")),
    );
  }
}
