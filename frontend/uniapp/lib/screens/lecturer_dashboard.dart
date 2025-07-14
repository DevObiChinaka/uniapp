import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/utils/utils.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uniapp/screens/attendance_management_screen.dart';

class LecturerDashboard extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String token;
  final String role;

  const LecturerDashboard({
    Key? key,
    required this.firstName,
    required this.lastName,
    required this.token,
    required this.role,
  }) : super(key: key);

  @override
  _LecturerDashboardState createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  final _sessionFormKey = GlobalKey<FormState>();
  String? _selectedProgram;
  int _totalSessions = AppConstants.defaultTotalSessions;
  double _passThreshold = AppConstants.defaultPassThreshold;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final activeSession = appProvider.activeSession;
    final isSessionActive = activeSession != null;
    final isBroadcasting = appProvider.isBleBroadcasting;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lecturer Dashboard'),
          actions: [
            // Add BLE status indicator
            if (isSessionActive && isBroadcasting)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Tooltip(
                  message: 'BLE beacon is active',
                  child: Icon(
                    Icons.bluetooth_searching,
                    color: Colors.blue,
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.account_circle),
              onPressed: () => _showProfileMenu(context),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Sessions'),
              Tab(text: 'Configuration'),
              Tab(text: 'Attendance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSessionsTab(appProvider),
            _buildConfigurationTab(appProvider),
            _buildAttendanceTab(appProvider),
          ],
        ),
        floatingActionButton:
            appProvider.inSession
                ? FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    await appProvider.endActiveSession();
                  },
                  child: Icon(Icons.stop),
                  tooltip: 'End Session',
                )
                : FloatingActionButton(
                  onPressed: () => _startSession(appProvider),
                  child: Icon(Icons.play_arrow),
                  tooltip: 'Start Session',
                ),
      ),
    );
  }

  Widget _buildSessionsTab(AppProvider appProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appProvider.inSession)
            _buildActiveSessionCard(appProvider.activeSession!),
          SizedBox(height: 16),
          Text(
            'Session History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          ...appProvider.sessions
              .where((s) => !s.isActive)
              .map((session) => _buildSessionCard(session))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(Session session) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE SESSION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text('Live'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.qr_code),
                  label: Text('Generate QR Code'),
                  onPressed: () => _showAttendanceQRCode(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Program: ${session.program}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Started: ${Utils.formatDateTime(session.startTime)}'),
            SizedBox(height: 8),
            Text('Total Sessions: ${session.totalSessions}'),
            SizedBox(height: 8),
            Text(
              'Pass Threshold: ${(session.passThreshold * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(session.program),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Utils.formatDateTime(session.startTime)} - '
              '${Utils.formatDateTime(session.endTime!)}',
            ),
            Text(
              '${session.totalSessions} sessions, '
              '${(session.passThreshold * 100).toStringAsFixed(1)}% threshold',
            ),
          ],
        ),
        trailing: Icon(Icons.history),
      ),
    );
  }

  Widget _buildConfigurationTab(AppProvider appProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _sessionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProgram,
              decoration: InputDecoration(
                labelText: 'Program',
                border: OutlineInputBorder(),
              ),
              items:
                  ['Computer Science', 'Engineering', 'Business', 'Medicine']
                      .map(
                        (program) => DropdownMenuItem(
                          value: program,
                          child: Text(program),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _selectedProgram = value),
              validator:
                  (value) => value == null ? 'Please select a program' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _totalSessions.toString(),
              decoration: InputDecoration(
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
            SizedBox(height: 16),
            TextFormField(
              initialValue: (_passThreshold * 100).toStringAsFixed(1),
              decoration: InputDecoration(
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
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_sessionFormKey.currentState!.validate()) {
                  appProvider.attendanceThreshold = _passThreshold;
                  appProvider.totalSessions = _totalSessions;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Configuration saved')),
                  );
                }
              },
              child: Text('Save Configuration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(AppProvider appProvider) {
    if (appProvider.activeSession == null) {
      return Center(
        child: Text('No active session. Start a session to track attendance.'),
      );
    }

    final session = appProvider.activeSession!;
    final attendanceRecords =
        appProvider.attendanceRecords
            .where((r) => r.sessionId == session.id)
            .toList();

    final studentAttendance = _calculateStudentAttendance(attendanceRecords);
    final flaggedStudents =
        studentAttendance.entries
            .where(
              (e) => (e.value / session.totalSessions) < session.passThreshold,
            )
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance: ${attendanceRecords.length} students',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('Manage'),
                    onPressed: () => _manageAttendance(session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Chip(
                    label: Text('Live'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: studentAttendance.length,
            itemBuilder: (context, index) {
              final studentId = studentAttendance.keys.elementAt(index);
              final count = studentAttendance.values.elementAt(index);
              final percentage = (count / session.totalSessions) * 100;
              final isFlagged = percentage < session.passThreshold * 100;

              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('Student ${studentId.substring(0, 6)}'),
                subtitle: LinearProgressIndicator(
                  value: count / session.totalSessions,
                  backgroundColor: Colors.grey[200],
                  color: isFlagged ? Colors.orange : Colors.green,
                ),
                trailing: Text(
                  '${Utils.formatPercentage(percentage)}',
                  style: TextStyle(
                    color: isFlagged ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        if (flaggedStudents.isNotEmpty) ...[
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Low Attendance Flags (${flaggedStudents.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
          ),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: flaggedStudents.length,
              itemBuilder: (context, index) {
                final studentId = flaggedStudents[index].key;
                final count = flaggedStudents[index].value;
                final percentage = (count / session.totalSessions) * 100;

                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Student ${studentId.substring(0, 6)}',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        Utils.formatPercentage(percentage),
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Map<String, int> _calculateStudentAttendance(List<AttendanceRecord> records) {
    final studentAttendance = <String, int>{};
    for (var record in records) {
      studentAttendance.update(
        record.userId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return studentAttendance;
  }

  Future<void> _startSession(AppProvider appProvider) async {
    if (_sessionFormKey.currentState!.validate()) {
      if (_selectedProgram == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select a program')));
        return;
      }
      final session = Session(
        id: Utils.generateSecureKey(),
        lecturerId: appProvider.userId!,
        program: _selectedProgram!,
        startTime: DateTime.now(),
        totalSessions: _totalSessions,
        passThreshold: _passThreshold,
      );
      final success = await appProvider.createSession(session);
      
      // Start BLE beacon automatically when session is created
      if (success) {
        await appProvider.startBleAttendanceBeacon(session.id);
      }
      
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Session started successfully')));
    }
  }

  void _showAttendanceQRCode(Session session) {
    // Create QR code data with session information and timestamp
    final qrData = jsonEncode({
      'session_id': session.id,
      'lecturer_id': session.lecturerId,
      'program': session.program,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance QR Code'),
        content: Container(
          width: 250,
          height: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Valid for 5 minutes',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageAttendance(Session session) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AttendanceManagementScreen(
          sessionId: session.id,
          program: session.program,
        ),
      ),
    );
    
    if (result == true) {
      // Refresh attendance data
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.fetchAttendanceRecords(session.id);
      setState(() {}); // Refresh UI
    }
  }
}
