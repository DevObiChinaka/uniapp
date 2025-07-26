import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/program.dart';
import '../../utils/utils.dart';
import 'package:uniapp/screens/lecturer/lecturer_qr_generation_screen.dart';

class LecturerSessionsScreen extends StatefulWidget {
  const LecturerSessionsScreen({super.key});

  @override
  State<LecturerSessionsScreen> createState() => _LecturerSessionsScreenState();
}

class _LecturerSessionsScreenState extends State<LecturerSessionsScreen> {
  void _activateSession(BuildContext context, Session session) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final success = await appProvider.activateSession(session.id);
    if (success) {
      // Start BLE beaconing for lecturer's own active session
      await appProvider.startBleBroadcast();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session activated and BLE beacon started')),
      );
      _refreshSessions();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate session')));
    }
  }

  void _deactivateSession(BuildContext context, Session session) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('End Session'),
            content: Text('Are you sure you want to end this session?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('End Session'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      final success = await appProvider.endSession(session.id);
      if (success) {
        await appProvider.stopBleBroadcast();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session ended and BLE beacon stopped')),
        );
        _refreshSessions();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to end session')));
      }
    }
  }

  void _showSessionDetailsModal(BuildContext context, Session session) {
    final programName = getProgramName(context, session.program);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Session Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Program: $programName',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Session ID: ${session.id}'),
                SizedBox(height: 8),
                Text('Started: ${Utils.formatDateTime(session.startTime)}'),
                if (session.endTime != null) ...[
                  SizedBox(height: 8),
                  Text('Ended: ${Utils.formatDateTime(session.endTime!)}'),
                ],
                SizedBox(height: 8),
                Text('Total Sessions: ${session.totalSessions}'),
                SizedBox(height: 8),
                Text(
                  'Current Period: Period ${session.currentPeriod} of ${session.totalSessions}',
                ),
                SizedBox(height: 8),
                Text(
                  'Pass Threshold: ${(session.passThreshold * 100).toStringAsFixed(1)}%',
                ),
                SizedBox(height: 8),
                Text('Status: ${session.isActive ? 'Active' : 'Ended'}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  static String getProgramName(BuildContext context, String programId) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final programObj = appProvider.programs.firstWhere(
      (p) => p.id.toString() == programId,
      orElse: () => Program(id: 0, name: programId),
    );
    return programObj.name;
  }

  Future<List<Session>>? _sessionsFuture;

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
                    .map((session) => _SessionHistoryCard(session: session)),
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
    final appProvider = Provider.of<AppProvider>(context);
    final bool isBleActive = appProvider.isBleBroadcasting;

    return Card(
      color: Colors.blue[50],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: ACTIVE SESSION + Live chip + Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE SESSION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                    fontSize: 17,
                    letterSpacing: 1.1,
                  ),
                ),
                Row(
                  children: [
                    // Live chip with green dot if BLE is active
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Live',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                            ],
                          ),
                          avatar: Icon(
                            Icons.circle,
                            size: 13,
                            color: Colors.white,
                          ),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          side: BorderSide.none,
                        ),
                        if (isBleActive)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blueGrey[700],
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      splashRadius: 20,
                      tooltip: 'Session Details',
                      onPressed:
                          () => _LecturerSessionsScreenState()
                              ._showSessionDetailsModal(context, session),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            // QR Button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: Icon(Icons.qr_code, size: 20),
                label: Text('QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => LecturerQrGenerationScreen(
                            sessionId: session.id,
                            program: session.program,
                          ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            // Info rows
            _InfoRow(
              icon: Icons.school,
              label: 'Program',
              value: _LecturerSessionsScreenState.getProgramName(
                context,
                session.program,
              ),
            ),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Started',
              value: Utils.formatDateTime(session.startTime),
            ),
            _InfoRow(
              icon: Icons.repeat,
              label: 'Total Sessions',
              value: '${session.totalSessions}',
            ),
            _InfoRow(
              icon: Icons.timelapse,
              label: 'Current Period',
              value:
                  'Period ${session.currentPeriod} of ${session.totalSessions}',
            ),
            _InfoRow(
              icon: Icons.percent,
              label: 'Pass Threshold',
              value: '${(session.passThreshold * 100).toStringAsFixed(1)}%',
            ),
            SizedBox(height: 16),
            // Stop button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.stop, size: 20),
                  label: Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final appProvider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    await appProvider.stopBleBroadcast();
                    _LecturerSessionsScreenState()._deactivateSession(
                      context,
                      session,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Removed old _showAttendanceQRCode dialog logic. Now uses LecturerQrGenerationScreen navigation.
}

// Helper widget for info rows
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[400]),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey[700],
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.blueGrey[900],
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(programName, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 4),
            Text(
              hasEndTime
                  ? '${Utils.formatDateTime(session.startTime)} - ${Utils.formatDateTime(session.endTime!)}'
                  : Utils.formatDateTime(session.startTime),
            ),
            Text(
              '${session.totalSessions} sessions, '
              '${(session.passThreshold * 100).toStringAsFixed(1)}% threshold',
            ),
            Text(
              'Current Period: Period ${session.currentPeriod} of ${session.totalSessions}',
            ),
            SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.play_arrow),
                  label: Text('Start Session'),
                  onPressed:
                      () => _LecturerSessionsScreenState()._activateSession(
                        context,
                        session,
                      ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.info_outline),
                  label: Text('View Details'),
                  onPressed:
                      () => _LecturerSessionsScreenState()
                          ._showSessionDetailsModal(context, session),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
