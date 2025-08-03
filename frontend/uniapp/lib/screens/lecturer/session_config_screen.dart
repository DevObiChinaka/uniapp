import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/program.dart' as prog;

class SessionConfigScreen extends StatefulWidget {
  final Session session;
  const SessionConfigScreen({super.key, required this.session});

  @override
  State<SessionConfigScreen> createState() => _SessionConfigScreenState();
}

class _SessionConfigScreenState extends State<SessionConfigScreen> {
  late TextEditingController _programController;
  late TextEditingController _totalSessionsController;
  late TextEditingController _passThresholdController;
  bool _isSaving = false;

  List<prog.Program> _programs = [];
  String? _selectedProgramId;

  // Level and course state
  final List<String> _levels = ['100', '200', '300', '400', '500'];
  String? _selectedLevel;
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    (() async {
      await appProvider.fetchPrograms();
      String? initialLevel = widget.session.level;
      String? initialCourseId = widget.session.courseId;
      setState(() {
        _programs = appProvider.programs;
        _selectedProgramId = widget.session.program;
        _selectedLevel = initialLevel;
        _selectedCourseId = initialCourseId;
      });
      // Auto-fetch courses if both program and level are set
      if (widget.session.program.isNotEmpty &&
          initialLevel != null &&
          initialLevel.isNotEmpty) {
        await _fetchCourses();
        setState(() {
          _selectedCourseId = initialCourseId;
        });
      }
    })();
    _programController = TextEditingController(text: widget.session.program);
    _totalSessionsController = TextEditingController(
      text: widget.session.totalSessions.toString(),
    );
    _passThresholdController = TextEditingController(
      text: (widget.session.passThreshold * 100).toStringAsFixed(0),
    );
  }

  Future<void> _fetchCourses() async {
    if (_selectedProgramId == null || _selectedLevel == null) {
      setState(() => _courses = []);
      return;
    }
    try {
      final dio = Dio();
      final response = await dio.get(
        'http://localhost:8000/api/courses/',
        queryParameters: {
          'program': _selectedProgramId,
          'level': _selectedLevel,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(response.data);
          _selectedCourseId = null;
        });
      } else {
        setState(() => _courses = []);
      }
    } catch (e) {
      setState(() => _courses = []);
    }
  }

  @override
  void dispose() {
    _programController.dispose();
    _totalSessionsController.dispose();
    _passThresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final program = _selectedProgramId ?? _programController.text.trim();
    final totalSessions = int.tryParse(_totalSessionsController.text.trim());
    final passThresholdRaw = double.tryParse(
      _passThresholdController.text.trim(),
    );
    final passThreshold =
        passThresholdRaw != null ? passThresholdRaw / 100 : null;

    if (program.isEmpty ||
        totalSessions == null ||
        passThreshold == null ||
        passThreshold <= 0 ||
        passThreshold > 1 ||
        _selectedLevel == null ||
        _selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all required session details.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      // If session id is empty or null, create new session
      if (widget.session.id.isEmpty) {
        final lecturerUsername = widget.session.lecturerUsername;
        final result = await appProvider.createSession(
          lecturerUsername: lecturerUsername,
          program: program,
          totalSessions: totalSessions,
          passThreshold: passThreshold,
          level: _selectedLevel!,
          courseId: _selectedCourseId!,
        );
        if (result == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session created successfully')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create session')),
          );
        }
      } else {
        final updatedSession = widget.session.copyWith(
          program: program,
          totalSessions: totalSessions,
          passThreshold: passThreshold,
          level: _selectedLevel,
          courseId: _selectedCourseId,
        );
        await appProvider.updateSession(updatedSession);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session updated successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Configuration')),
      body:
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
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
                      onChanged: (val) {
                        setState(() {
                          _selectedProgramId = val;
                          _programController.text = val ?? '';
                          _selectedLevel = null;
                          _selectedCourseId = null;
                        });
                        // Clear level and course when program changes
                      },
                      decoration: const InputDecoration(
                        labelText: 'Program',
                        helperText: 'Required',
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      onChanged: (val) async {
                        setState(() {
                          _selectedLevel = val;
                          _selectedCourseId = null;
                        });
                        await _fetchCourses();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        helperText: 'Required',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCourseId,
                      items:
                          _courses
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id'].toString(),
                                  child: Text('${c['code']} - ${c['name']}'),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCourseId = val;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Course',
                        helperText: 'Required. Select program and level first.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalSessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Sessions',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pass Threshold (%)',
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
