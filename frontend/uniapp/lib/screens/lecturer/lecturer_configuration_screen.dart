import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/program.dart';
import '../../models/models.dart';

class LecturerConfigurationScreen extends StatefulWidget {
  const LecturerConfigurationScreen({super.key});

  @override
  State<LecturerConfigurationScreen> createState() =>
      _LecturerConfigurationScreenState();
}

class _LecturerConfigurationScreenState
    extends State<LecturerConfigurationScreen> {
  final _sessionFormKey = GlobalKey<FormState>();
  Program? _selectedProgram;
  int _totalSessions = 12;
  double _passThreshold = 0.75;
  bool _isCreating = false;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.loadUserData();
      await appProvider.fetchPrograms();
    });
  }

  Future<void> _createSession(BuildContext context) async {
    if (!_sessionFormKey.currentState!.validate() ||
        _selectedProgram == null ||
        _startTime == null ||
        _endTime == null) {
      debugPrint('Form validation failed or missing required fields');
      return;
    }
    setState(() => _isCreating = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final lecturerUsername = appProvider.getCurrentUser()?.username ?? '';
    debugPrint('Lecturer username: $lecturerUsername');
    final totalSessions = _totalSessions;
    final passThreshold = _passThreshold;
    final payload = {
      'lecturer': lecturerUsername,
      'program': _selectedProgram!.id,
      'start_time': _startTime!.toIso8601String(),
      'end_time': _endTime!.toIso8601String(),
      'total_sessions': totalSessions,
      'pass_threshold': passThreshold,
    };
    debugPrint('Creating session with payload: $payload');
    final result = await appProvider.coreServices.dio.post(
      '/sessions/',
      data: payload,
    );
    debugPrint('Backend response status: ${result.statusCode}');
    debugPrint('Backend response data: ${result.data}');
    setState(() => _isCreating = false);
    if (result.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session created successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create session: ${result.data['error'] ?? 'Unknown error'}',
          ),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.fetchPrograms();
    // Fetch sessions for the current lecturer using username
    final lecturerUsername = appProvider.getCurrentUser()?.username ?? '';
    debugPrint('Refreshing sessions for lecturer: $lecturerUsername');
    await appProvider.coreServices.dio.get(
      '/sessions/',
      queryParameters: {'username': lecturerUsername},
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final programs = appProvider.programs;
    return Scaffold(
      appBar: AppBar(title: const Text('Session Configuration')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _sessionFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a new session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                programs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<Program>(
                      value: _selectedProgram,
                      decoration: const InputDecoration(
                        labelText: 'Program',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          programs
                              .map(
                                (program) => DropdownMenuItem(
                                  value: program,
                                  child: Text(program.name),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(() => _selectedProgram = value),
                      validator:
                          (value) =>
                              value == null ? 'Please select a program' : null,
                    ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _totalSessions.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Total Sessions',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter total sessions';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 1) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final num = int.tryParse(value);
                    if (num != null) {
                      setState(() => _totalSessions = num);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: (_passThreshold * 100).toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'Pass Threshold (%)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pass threshold';
                    }
                    final percent = double.tryParse(value);
                    if (percent == null || percent < 0 || percent > 100) {
                      return 'Please enter a valid percentage';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final percent = double.tryParse(value);
                    if (percent != null) {
                      setState(() => _passThreshold = percent / 100);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _startTime == null
                            ? 'Start Time: Not selected'
                            : 'Start Time: ${_startTime!.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                    TextButton(
                      child: const Text('Pick Start'),
                      onPressed: () async {
                        final picked = await showDateTimePicker(
                          context,
                          _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _endTime == null
                            ? 'End Time: Not selected'
                            : 'End Time: ${_endTime!.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                    TextButton(
                      child: const Text('Pick End'),
                      onPressed: () async {
                        final picked = await showDateTimePicker(
                          context,
                          _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label:
                      _isCreating
                          ? const Text('Creating...')
                          : const Text('Create Session'),
                  onPressed:
                      _isCreating || programs.isEmpty
                          ? null
                          : () => _createSession(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for picking date and time
  Future<DateTime?> showDateTimePicker(
    BuildContext context,
    DateTime? initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
