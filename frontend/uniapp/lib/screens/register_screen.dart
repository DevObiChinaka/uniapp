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
  final List<String> _roles = ['student', 'lecturer', 'security', 'admin'];

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
      appBar: AppBar(title: const Text('User Registration')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items:
                    _roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(
                              role[0].toUpperCase() + role.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) {
                  setState(() => _selectedRole = val ?? 'student');
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (val) => val!.isEmpty ? 'Enter first name' : null,
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (val) => val!.isEmpty ? 'Enter last name' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator:
                    (val) =>
                        val != null && val.isNotEmpty && !val.contains('@')
                            ? 'Enter a valid email'
                            : null,
              ),
              if (isStudent)
                DropdownButtonFormField<String>(
                  value: campusTag,
                  items:
                      campusTags
                          .map(
                            (tag) => DropdownMenuItem(
                              value: tag,
                              child: Text(
                                tag == 'on-campus' ? 'On Campus' : 'Off Campus',
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (val) => setState(() => campusTag = val ?? 'on-campus'),
                  decoration: const InputDecoration(labelText: 'Campus Tag'),
                ),
              if (isStudent)
                DropdownButtonFormField<String>(
                  value: _selectedProgramId,
                  items:
                      _programs
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id.toString(),
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _selectedProgramId = val),
                  decoration: const InputDecoration(labelText: 'Program'),
                  validator:
                      (val) =>
                          val == null || val.isEmpty ? 'Select program' : null,
                ),
              if (isStudent)
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  items:
                      _levels
                          .map(
                            (l) => DropdownMenuItem<String>(
                              value: l,
                              child: Text('$l Level'),
                            ),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _selectedLevel = val),
                  decoration: const InputDecoration(labelText: 'Level'),
                  validator:
                      (val) =>
                          val == null || val.isEmpty ? 'Select level' : null,
                ),
              TextFormField(
                controller: universityIdController,
                decoration: InputDecoration(
                  labelText: isStudent ? 'University ID' : 'Username',
                ),
                validator:
                    (val) =>
                        val!.isEmpty
                            ? (isStudent
                                ? 'Enter university ID'
                                : 'Enter username')
                            : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _register,
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () {
                      context.go(routes.AppRoutes.login);
                    },
                    child: const Text('Login'),
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
