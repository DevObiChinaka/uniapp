import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/utils/utils.dart';

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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lecturer Dashboard'),
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
              Chip(
                label: Text('Live'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white),
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
      await appProvider.createSession(session);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Session started successfully')));
    }
  }
}
