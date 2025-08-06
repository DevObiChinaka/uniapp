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
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSession();
  }

  Future<void> _fetchSession() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final user = appProvider.getCurrentUser();
      final username = user?.username;

      if (username == null || username.isEmpty) {
        throw Exception('Please log in to continue');
      }

      // Start both fetches in parallel
      final sessionsFuture = appProvider.fetchLecturerSessions(username);
      final programsFuture = appProvider.fetchPrograms();

      // Wait for both to complete
      final results = await Future.wait([sessionsFuture, programsFuture]);
      final sessions = results[0] as List<Session>;

      // Find active or most recent session
      Session? activeSession;
      if (sessions.isNotEmpty) {
        activeSession = sessions.firstWhere(
          (s) => s.isActive,
          orElse:
              () => sessions
                  .where((s) => s.endTime?.isAfter(DateTime.now()) ?? true)
                  .fold(
                    sessions.first,
                    (a, b) => a.startTime.isAfter(b.startTime) ? a : b,
                  ),
        );
      }

      if (mounted) {
        setState(() {
          _session = activeSession;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchSession,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSession,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No active sessions found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => SessionConfigScreen(
                          session:
                              Session.empty(), // Using empty session for new creation
                        ),
                  ),
                );
                if (result == true) {
                  _fetchSession();
                }
              },
              child: const Text('Create Session'),
            ),
          ],
        ),
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
      await _refreshAttendanceData(session);
    }
  }

  Future<void> _refreshAttendanceData(Session session) async {
    setState(() => _loading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.fetchAttendanceRecords(session.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => ManageAttendanceScreen()));
    await _refreshAttendanceData(session);
  }
}
