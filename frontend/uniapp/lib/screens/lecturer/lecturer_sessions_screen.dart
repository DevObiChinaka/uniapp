import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/program.dart';
import '../../utils/utils.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';

class LecturerSessionsScreen extends StatefulWidget {
  const LecturerSessionsScreen({Key? key}) : super(key: key);

  @override
  State<LecturerSessionsScreen> createState() => _LecturerSessionsScreenState();
}

class _LecturerSessionsScreenState extends State<LecturerSessionsScreen> {
  static String getProgramName(BuildContext context, String programId) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final programObj = appProvider.programs.firstWhere(
      (p) => p.id.toString() == programId,
      orElse: () => Program(id: 0, name: programId),
    );
    return programObj.name;
  }

  Future<List<Session>>? _sessionsFuture;
  String? _lecturerUsername;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    (() async {
      await appProvider.loadUserData();
      await appProvider.fetchPrograms();
      final username = appProvider.getCurrentUser()?.username;
      debugPrint(
        'LecturerSessionsScreen: getCurrentUser()?.username = $username',
      );
      String lecturerUsername = '';
      if (username != null && username.isNotEmpty) {
        lecturerUsername = username;
      } else {
        debugPrint(
          'LecturerSessionsScreen: WARNING - No valid lecturer username found.',
        );
      }
      debugPrint(
        'LecturerSessionsScreen: Using lecturerUsername for fetchLecturerSessions: $lecturerUsername',
      );
      setState(() {
        _lecturerUsername = lecturerUsername;
        _sessionsFuture =
            lecturerUsername.isNotEmpty
                ? appProvider.fetchLecturerSessions(lecturerUsername)
                : Future.value([]);
      });
    })();
  }

  Future<void> _refreshSessions() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.loadUserData();
    await appProvider.fetchPrograms();
    final username = appProvider.getCurrentUser()?.username;
    debugPrint(
      'LecturerSessionsScreen: (refresh) getCurrentUser()?.username = $username',
    );
    String lecturerUsername = '';
    if (username != null && username.isNotEmpty) {
      lecturerUsername = username;
    } else {
      debugPrint(
        'LecturerSessionsScreen: (refresh) WARNING - No valid lecturer username found.',
      );
    }
    debugPrint(
      'LecturerSessionsScreen: (refresh) Using lecturerUsername for fetchLecturerSessions: $lecturerUsername',
    );
    setState(() {
      _lecturerUsername = lecturerUsername;
      _sessionsFuture =
          lecturerUsername.isNotEmpty
              ? appProvider.fetchLecturerSessions(lecturerUsername)
              : Future.value([]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshSessions,
      child: FutureBuilder<List<Session>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (_sessionsFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('LecturerSessionsScreen: Waiting for sessions data...');
            return Scaffold(
              appBar: AppBar(title: Text('Sessions')),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            debugPrint(
              'LecturerSessionsScreen: Error loading sessions: ${snapshot.error}',
            );
            return Scaffold(
              appBar: AppBar(title: Text('Sessions')),
              body: Center(child: Text('Error loading sessions')),
            );
          }
          final sessions = snapshot.data ?? [];
          debugPrint(
            'LecturerSessionsScreen: API response sessions count: ${sessions.length}',
          );
          for (var s in sessions) {
            debugPrint(
              'Session: id=${s.id}, program=${s.program}, isActive=${s.isActive}, lecturerUsername=${s.lecturerUsername}',
            );
          }
          if (sessions.isEmpty) {
            debugPrint(
              'LecturerSessionsScreen: No sessions found for this lecturer',
            );
            return Scaffold(
              appBar: AppBar(title: Text('Sessions')),
              body: Center(child: Text('No sessions found for this lecturer')),
            );
          }
          final Session? activeSession =
              sessions.where((s) => s.isActive).isNotEmpty
                  ? sessions.firstWhere((s) => s.isActive)
                  : null;
          debugPrint(
            'LecturerSessionsScreen: Active session: ${activeSession?.id ?? "none"}',
          );
          return Scaffold(
            appBar: AppBar(title: Text('Sessions')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeSession != null)
                  _ActiveSessionCard(session: activeSession),
                SizedBox(height: 16),
                Text(
                  'Session History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                ...sessions
                    .where((s) => !s.isActive)
                    .map((session) => _SessionHistoryCard(session: session))
                    .toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final Session session;
  const _ActiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () => _showAttendanceQRCode(context, session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Program: ${_LecturerSessionsScreenState.getProgramName(context, session.program)}',
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

  void _showAttendanceQRCode(BuildContext context, Session session) {
    final programName = _LecturerSessionsScreenState.getProgramName(
      context,
      session.program,
    );
    final qrData = jsonEncode({
      'session_id': session.id,
      'lecturer': session.lecturerUsername,
      'program': programName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  final Session session;
  const _SessionHistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final hasEndTime = session.endTime != null;
    final programName = _LecturerSessionsScreenState.getProgramName(
      context,
      session.program,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(programName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasEndTime
                  ? '${Utils.formatDateTime(session.startTime)} - ${Utils.formatDateTime(session.endTime!)}'
                  : '${Utils.formatDateTime(session.startTime)}',
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
}
