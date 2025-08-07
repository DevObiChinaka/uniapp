// lib/screens/register_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:uniapp/services/api_service.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart' as routes;
import '../models/program.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final universityIdController = TextEditingController();
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  String campusTag = 'on-campus';
  final List<String> campusTags = ['on-campus', 'off-campus'];
  bool isLoading = false;
  String _selectedRole = 'student';
  final List<String> _roles = [
    'student',
    'lecturer',
  ]; // Only allow student/lecturer registration from frontend
  bool _obscurePassword = true;

  // Program/level state
  List<Program> _programs = [];
  String? _selectedProgramId;
  final List<String> _levels = ['100', '200', '300', '400', '500'];
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
  }

  Future<void> _fetchPrograms() async {
    try {
      final response = await ApiService.get('/programs/');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('results')) {
          data = decoded['results'];
        } else {
          data = [];
        }
        setState(() {
          _programs = data.map<Program>((e) => Program.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final payload = {
      'first_name': firstNameController.text.trim(),
      'last_name': lastNameController.text.trim(),
      'role': _selectedRole,
      'password': passwordController.text,
      'email': emailController.text.trim(),
      'university_id':
          _selectedRole == 'student'
              ? universityIdController.text.trim()
              : null,
      'username':
          _selectedRole == 'student'
              ? null
              : universityIdController.text.trim(),
      'campus_tag': _selectedRole == 'student' ? campusTag : null,
      'program': _selectedRole == 'student' ? _selectedProgramId : null,
      'level': _selectedRole == 'student' ? _selectedLevel : null,
    };

    print('Register payload: $payload'); // <-- LOGGING

    final response = await ApiService.postAndDecode('/register/', payload);
    print('Register response: $response'); // <-- LOGGING
    final data = response['body'];
    final status = response['statusCode'];

    setState(() => isLoading = false);

    if (status == 201 || status == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Please log in.'),
        ),
      );
      context.go(routes.AppRoutes.login); // Go to login page using GoRouter
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['detail'] ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _selectedRole == 'student';
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
                  SizedBox(height: 40),

                  // Logo and Welcome Section
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Join SALMS',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Create your account to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Registration Form Container
                  Container(
                    padding: EdgeInsets.all(24),
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Fill in your details to register',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 24),

                          // Role Selection
                          _buildSectionTitle('Select Role'),
                          Text(
                            'Note: Admin and Security accounts are created by system administrators',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildDropdownField(
                            value: _selectedRole,
                            items:
                                _roles
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getRoleIcon(role),
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                              size: 18,
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _getRoleDisplayName(role),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[800],
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() => _selectedRole = val ?? 'student');
                            },
                          ),

                          SizedBox(height: 16),

                          // Personal Information
                          _buildSectionTitle('Personal Information'),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: firstNameController,
                                  label: 'First Name',
                                  hint: 'Enter your first name',
                                  icon: Icons.person_outline,
                                  validator:
                                      (val) =>
                                          val!.isEmpty
                                              ? 'Enter first name'
                                              : null,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: lastNameController,
                                  label: 'Last Name',
                                  hint: 'Enter your last name',
                                  icon: Icons.person_outline,
                                  validator:
                                      (val) =>
                                          val!.isEmpty
                                              ? 'Enter last name'
                                              : null,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          _buildTextField(
                            controller: emailController,
                            label: 'Email Address',
                            hint: 'Enter your email address',
                            icon: Icons.email_outlined,
                            validator:
                                (val) =>
                                    val != null &&
                                            val.isNotEmpty &&
                                            !val.contains('@')
                                        ? 'Enter a valid email'
                                        : null,
                          ),

                          SizedBox(height: 16),

                          // Student-specific fields
                          if (isStudent) ...[
                            _buildSectionTitle('Academic Information'),
                            SizedBox(height: 12),

                            _buildDropdownField(
                              value: campusTag,
                              items:
                                  campusTags
                                      .map(
                                        (tag) => DropdownMenuItem(
                                          value: tag,
                                          child: Row(
                                            children: [
                                              Icon(
                                                tag == 'on-campus'
                                                    ? Icons.school_outlined
                                                    : Icons.home_outlined,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                size: 18,
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  tag == 'on-campus'
                                                      ? 'On Campus'
                                                      : 'Off Campus',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[800],
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (val) => setState(
                                    () => campusTag = val ?? 'on-campus',
                                  ),
                              label: 'Campus Status',
                            ),

                            SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdownField(
                                    value: _selectedProgramId,
                                    items:
                                        _programs
                                            .map(
                                              (p) => DropdownMenuItem<String>(
                                                value: p.id.toString(),
                                                child: Container(
                                                  width: double.infinity,
                                                  child: Text(
                                                    p.name,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.grey[800],
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (val) => setState(
                                          () => _selectedProgramId = val,
                                        ),
                                    label: 'Program',
                                    validator:
                                        (val) =>
                                            val == null || val.isEmpty
                                                ? 'Select program'
                                                : null,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildDropdownField(
                                    value: _selectedLevel,
                                    items:
                                        _levels
                                            .map(
                                              (l) => DropdownMenuItem<String>(
                                                value: l,
                                                child: Container(
                                                  width: double.infinity,
                                                  child: Text(
                                                    '$l Level',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.grey[800],
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (val) => setState(
                                          () => _selectedLevel = val,
                                        ),
                                    label: 'Level',
                                    validator:
                                        (val) =>
                                            val == null || val.isEmpty
                                                ? 'Select level'
                                                : null,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),
                          ],

                          // Account Information
                          _buildSectionTitle('Account Information'),
                          SizedBox(height: 12),

                          _buildTextField(
                            controller: universityIdController,
                            label: isStudent ? 'University ID' : 'Username',
                            hint:
                                isStudent
                                    ? 'Enter your university ID'
                                    : 'Enter your username',
                            icon:
                                isStudent
                                    ? Icons.badge_outlined
                                    : Icons.person_outline,
                            validator:
                                (val) =>
                                    val!.isEmpty
                                        ? (isStudent
                                            ? 'Enter university ID'
                                            : 'Enter username')
                                        : null,
                          ),

                          SizedBox(height: 16),

                          _buildPasswordField(),

                          SizedBox(height: 28),

                          // Register Button
                          Container(
                            height: 52,
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
                              onPressed: isLoading ? null : _register,
                              child:
                                  isLoading
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
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
                                            'Creating Account...',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                      : Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.go(routes.AppRoutes.login);
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
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
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey[600],
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? label,
    String? Function(T?)? validator,
  }) {
    Widget dropdown = Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true, // This ensures the dropdown takes full width
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
        // Add custom dropdown style to prevent overflow
        menuMaxHeight: 200, // Limit dropdown menu height
        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
      ),
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 6),
          dropdown,
        ],
      );
    }

    return dropdown;
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
