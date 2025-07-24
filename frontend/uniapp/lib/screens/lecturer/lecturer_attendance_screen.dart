import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'manage_attendance_screen.dart';
import 'manual_attendance_screen.dart';
import 'session_config_screen.dart';

class LecturerAttendanceScreen extends StatefulWidget {
  const LecturerAttendanceScreen({super.key});

  @override
  State<LecturerAttendanceScreen> createState() =>
      _LecturerAttendanceScreenState();
}

class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen> {
  Session? _session;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchSession();
  }

  Future<void> _fetchSession() async {
    setState(() => _loading = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final username = appProvider.getCurrentUser()?.username ?? '';
    final sessions = await appProvider.fetchLecturerSessions(username);
    await appProvider.fetchPrograms();
    Session? activeSession;
    try {
      activeSession = sessions.firstWhere((s) => s.isActive);
    } catch (_) {
      if (sessions.isNotEmpty) {
        activeSession = sessions.first;
      }
    }
    setState(() {
      _session = activeSession;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Attendance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Attendance')),
        body: Center(child: Text('No sessions available.')),
      );
    }
    final appProvider = Provider.of<AppProvider>(context);
    final attendanceRecords =
        appProvider.attendanceRecords
            .where((r) => r.sessionId == session.id)
            .toList();
    final studentAttendance = _calculateStudentAttendance(
      attendanceRecords,
      session.totalSessions,
    );
    final flaggedStudents =
        studentAttendance.entries
            .where(
              (e) => (e.value / session.totalSessions) < session.passThreshold,
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Session Config',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SessionConfigScreen(session: session),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
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
                      onPressed: () => _manageAttendance(context, session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.how_to_reg),
                      label: Text('Mark Attendance'),
                      onPressed: () => _markManualAttendance(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
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
                    Utils.formatPercentage(percentage),
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
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: flaggedStudents.length,
                itemBuilder: (context, index) {
                  final studentId = flaggedStudents[index].key;
                  final count = flaggedStudents[index].value;
                  final percentage = (count / session.totalSessions) * 100;
                  return Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Student ${studentId.substring(0, 6)}',
                              style: TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              Utils.formatPercentage(percentage),
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markManualAttendance(Session session) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManualAttendanceScreen(session: session),
      ),
    );
    if (result == true) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.fetchAttendanceRecords(session.id);
      setState(() {});
    }
  }

  Map<String, int> _calculateStudentAttendance(
    List<AttendanceRecord> records,
    int totalSessions,
  ) {
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

  Future<void> _manageAttendance(BuildContext context, Session session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManageAttendanceScreen(session: session),
      ),
    );
  }
}
