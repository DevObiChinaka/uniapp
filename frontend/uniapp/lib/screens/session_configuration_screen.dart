import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/qr_generation_screen.dart';
// import 'package:uniapp/models/models.dart'; // Removed unused import
import 'package:intl/intl.dart';

class SessionConfigurationScreen extends StatefulWidget {
  final String lecturerId;
  final String token;

  const SessionConfigurationScreen({
    Key? key,
    required this.lecturerId,
    required this.token,
  }) : super(key: key);

  @override
  State<SessionConfigurationScreen> createState() =>
      _SessionConfigurationScreenState();
}

class _SessionConfigurationScreenState
    extends State<SessionConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _program = '';
  int _totalSessions = AppConstants.defaultTotalSessions;
  double _passThreshold = AppConstants.defaultPassThreshold;
  bool _isSubmitting = false;

  final List<String> _programOptions = [
    'Computer Science',
    'Engineering',
    'Business Administration',
    'Medicine',
    'Law',
    'Arts & Humanities',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configure Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                margin: EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'New Attendance Session',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Configure the details for the new attendance session. Students will use this information to mark their attendance.',
                      ),
                    ],
                  ),
                ),
              ),

              Text(
                'Session Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 16),

              // Program Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Program',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                items:
                    _programOptions.map((program) {
                      return DropdownMenuItem(
                        value: program,
                        child: Text(program),
                      );
                    }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a program';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _program = value!;
                  });
                },
              ),
              SizedBox(height: 20),

              // Session Count Slider
              Text(
                'Total Number of Sessions: $_totalSessions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _totalSessions.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: _totalSessions.toString(),
                onChanged: (value) {
                  setState(() {
                    _totalSessions = value.round();
                  });
                },
              ),
              SizedBox(height: 20),

              // Pass Threshold Slider
              Text(
                'Attendance Pass Threshold: ${(_passThreshold * 100).round()}%',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _passThreshold,
                min: 0.5,
                max: 1.0,
                divisions: 10,
                label: '${(_passThreshold * 100).round()}%',
                onChanged: (value) {
                  setState(() {
                    _passThreshold = value;
                  });
                },
              ),
              SizedBox(height: 20),

              // Current Date & Time
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Date & Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(DateTime.now()),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(DateFormat('h:mm a').format(DateTime.now())),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Start Session Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: Icon(_isSubmitting ? null : Icons.play_circle_filled),
                  label:
                      _isSubmitting
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          )
                          : Text('Start Attendance Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _startSession,
                ),
              ),
              SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);

      // Create a new session
      final sessionId = await appProvider.createSession(
        lecturer_username: widget.lecturer_username,
        program: _program,
        totalSessions: _totalSessions,
        passThreshold: _passThreshold,
      );

      if (sessionId.isEmpty) {
        _showSnackBar('Failed to create session');
        setState(() => _isSubmitting = false);
        return;
      }

      // Navigate to QR generation screen
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  QrGenerationScreen(sessionId: sessionId, program: _program),
        ),
      );
    } catch (e) {
      print('Error starting session: $e');
      _showSnackBar('Error: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
