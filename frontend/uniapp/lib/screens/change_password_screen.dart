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
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.security,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Security Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Please enter your current password to proceed with changing your password.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          hintText: 'Enter your current password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      if (verifyError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
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
                                    verifyError,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: verifying ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
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
                                  () =>
                                      verifyError =
                                          'Incorrect password. Please try again.',
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        verifying
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Verify',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.security, size: 48, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Security First',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Keep your account secure with a strong password',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form Section
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Verification Status Card
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                isVerified
                                    ? Colors.green[50]
                                    : Colors.orange[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isVerified
                                      ? Colors.green[200]!
                                      : Colors.orange[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      isVerified
                                          ? Colors.green[100]
                                          : Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isVerified
                                      ? Icons.verified_user
                                      : Icons.warning_amber,
                                  color:
                                      isVerified
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVerified
                                          ? 'Identity Verified'
                                          : 'Verification Required',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isVerified
                                                ? Colors.green[700]
                                                : Colors.orange[700],
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      isVerified
                                          ? 'You can now change your password'
                                          : 'Please verify your current password first',
                                      style: TextStyle(
                                        color:
                                            isVerified
                                                ? Colors.green[600]
                                                : Colors.orange[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isVerified)
                                ElevatedButton(
                                  onPressed: _showVerifyDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[600],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Verify',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Password Change Form
                        if (isVerified) ...[
                          Text(
                            'New Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // New Password Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: newPasswordController,
                                    obscureText: !_showNewPassword,
                                    decoration: InputDecoration(
                                      labelText: 'New Password',
                                      hintText: 'Enter your new password',
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showNewPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _showNewPassword =
                                                      !_showNewPassword,
                                            ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),
                                ),

                                SizedBox(height: 16),

                                // Confirm Password Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextFormField(
                                    controller: confirmPasswordController,
                                    obscureText: !_showConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      hintText: 'Re-enter your new password',
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showConfirmPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _showConfirmPassword =
                                                      !_showConfirmPassword,
                                            ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
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
                                ),

                                SizedBox(height: 24),

                                // Password Requirements
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.blue[700],
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Password Requirements',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '• At least 8 characters long\n• Include a special character\n• Avoid common passwords',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (error.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red[200]!,
                                        ),
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
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                SizedBox(height: 32),

                                // Change Password Button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading ? null : _changePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
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
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Updating Password...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Text(
                                              'Change Password',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
