import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/course.dart';
import '../../utils/utils.dart';
import 'package:uniapp/screens/lecturer/lecturer_qr_generation_screen.dart';

class LecturerSessionsScreen extends StatefulWidget {
  const LecturerSessionsScreen({super.key});

  @override
  State<LecturerSessionsScreen> createState() => _LecturerSessionsScreenState();
}

class _LecturerSessionsScreenState extends State<LecturerSessionsScreen> {
  bool _isLoading = false;
  Map<String, Course> _courseDetails = {};

  Future<void> _loadCourseDetails(List<Session> sessions) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final uniqueCourseIds =
        sessions
            .where((s) => s.courseId?.isNotEmpty == true)
            .map((s) => s.courseId!)
            .toSet();

    final courseDetails = <String, Course>{};
    for (final courseId in uniqueCourseIds) {
      try {
        final course = await appProvider.coreServices.getCourse(courseId);
        if (course != null) {
          courseDetails[courseId] = course;
        }
      } catch (e) {
        debugPrint('Error fetching course details for $courseId: $e');
      }
    }

    setState(() {
      _courseDetails = courseDetails;
    });
  }

  String _getCourseDisplayName(String? courseId) {
    if (courseId == null || courseId.isEmpty) return 'Unknown Course';

    final course = _courseDetails[courseId];
    if (course != null) {
      if (course.code.isNotEmpty && !RegExp(r'^\d+$').hasMatch(course.code)) {
        return course.code;
      }
      if (course.name.contains(' - ')) {
        final parts = course.name.split(' - ');
        if (parts.isNotEmpty) {
          return parts[0];
        }
      }
    }
    return 'Course $courseId';
  }

  Future<void> _deleteSession(BuildContext context, Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Session'),
            content: Text(
              'Are you sure you want to delete this session? This cannot be undone.',
            ),
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
                child: Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      final coreServices =
          Provider.of<AppProvider>(context, listen: false).coreServices;
      final success = await coreServices.deleteSession(session.id);
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Session deleted.')));
        _refreshSessions();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete session.')));
      }
    }
  }

  void _activateSession(BuildContext context, Session session) async {
    setState(() => _isLoading = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final success = await appProvider.activateSession(session.id);
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session activated. Location is now being used for attendance.',
          ),
        ),
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
            title: Text('Stop Session'),
            content: Text('Are you sure you want to stop this session?'),
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
      setState(() => _isLoading = true);
      final success = await appProvider.endSession(session.id);
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Session ended.')));
        _refreshSessions();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to end session')));
      }
    }
  }

  void _showSessionDetailsModal(BuildContext context, Session session) {
    final courseDisplayName = _getCourseDisplayName(session.courseId);
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
                  'Course: $courseDisplayName',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                _DialogInfoRow(label: 'Session ID', value: session.id),
                _DialogInfoRow(
                  label: 'Started',
                  value: Utils.formatDateTime(session.startTime),
                ),
                if (session.endTime != null)
                  _DialogInfoRow(
                    label: 'Ended',
                    value: Utils.formatDateTime(session.endTime!),
                  ),
                _DialogInfoRow(
                  label: 'Total Sessions',
                  value: '${session.totalSessions}',
                ),
                _DialogInfoRow(
                  label: 'Current Period',
                  value:
                      'Period ${session.currentPeriod} of ${session.totalSessions}',
                ),
                _DialogInfoRow(
                  label: 'Pass Threshold',
                  value: '${(session.passThreshold * 100).toStringAsFixed(1)}%',
                ),
                _DialogInfoRow(
                  label: 'Status',
                  value: session.isActive ? 'Active' : 'Ended',
                ),
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

  Widget _DialogInfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
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
                ? appProvider.coreServices.getSessions(
                  lecturerUsername,
                  isStudent: false,
                )
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
              ? appProvider.coreServices.getSessions(
                lecturerUsername,
                isStudent: false,
              )
              : Future.value([]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshSessions,
          child: FutureBuilder<List<Session>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (_sessionsFuture == null ||
                  snapshot.connectionState == ConnectionState.waiting) {
                debugPrint(
                  'LecturerSessionsScreen: Waiting for sessions data...',
                );
                return Scaffold(
                  appBar: AppBar(title: Text('Sessions')),
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                debugPrint(
                  'LecturerSessionsScreen: Error loading sessions: \\${snapshot.error}',
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

              // Load course details for all sessions
              _loadCourseDetails(sessions);
              if (sessions.isEmpty) {
                debugPrint(
                  'LecturerSessionsScreen: No sessions found for this lecturer',
                );
                return Scaffold(
                  appBar: AppBar(title: Text('Sessions')),
                  body: Center(
                    child: Text('No sessions found for this lecturer'),
                  ),
                );
              }
              final Session? activeSession =
                  sessions.where((s) => s.isActive).isNotEmpty
                      ? sessions.firstWhere((s) => s.isActive)
                      : null;
              debugPrint(
                'LecturerSessionsScreen: Active session: \\${activeSession?.id ?? "none"}',
              );
              return Scaffold(
                appBar: AppBar(
                  title: Text('Sessions'),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (activeSession != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Active Session',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _ActiveSessionCard(
                        session: activeSession,
                        courseDisplayName: _getCourseDisplayName(
                          activeSession.courseId,
                        ),
                        onDeactivate: (s) => _deactivateSession(context, s),
                        onShowDetails:
                            (s) => _showSessionDetailsModal(context, s),
                      ),
                      SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Session History',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (sessions.where((s) => !s.isActive).isEmpty)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No session history yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Previous sessions will appear here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...sessions
                          .where((s) => !s.isActive)
                          .map(
                            (session) => _SessionHistoryCard(
                              session: session,
                              courseDisplayName: _getCourseDisplayName(
                                session.courseId,
                              ),
                              onDelete: (s) => _deleteSession(context, s),
                              onActivate: (s) => _activateSession(context, s),
                              onShowDetails:
                                  (s) => _showSessionDetailsModal(context, s),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final Session session;
  final String courseDisplayName;
  final void Function(Session)? onDeactivate;
  final void Function(Session)? onShowDetails;

  const _ActiveSessionCard({
    required this.session,
    required this.courseDisplayName,
    this.onDeactivate,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.green[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Course Code and Live Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      courseDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Session Info
              _InfoRow(
                icon: Icons.access_time,
                label: 'Started',
                value: Utils.formatDateTime(session.startTime),
              ),
              _InfoRow(
                icon: Icons.repeat,
                label: 'Session',
                value:
                    'Period ${session.currentPeriod} of ${session.totalSessions}',
              ),
              _InfoRow(
                icon: Icons.percent,
                label: 'Pass Threshold',
                value: '${(session.passThreshold * 100).toStringAsFixed(1)}%',
              ),

              SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.qr_code, size: 20),
                      label: Text('Show QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.info_outline, size: 20),
                    label: Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed:
                        onShowDetails != null
                            ? () => onShowDetails!(session)
                            : null,
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Stop Session Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.stop, size: 20),
                  label: Text('End Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      onDeactivate != null
                          ? () => onDeactivate!(session)
                          : null,
                ),
              ),
            ],
          ),
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
  final String courseDisplayName;
  final void Function(Session)? onDelete;
  final void Function(Session)? onActivate;
  final void Function(Session)? onShowDetails;

  const _SessionHistoryCard({
    required this.session,
    required this.courseDisplayName,
    this.onDelete,
    this.onActivate,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final hasEndTime = session.endTime != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Code Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  courseDisplayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Ended',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Session Details
            _InfoRow(
              icon: Icons.access_time,
              label: 'Duration',
              value:
                  hasEndTime
                      ? '${Utils.formatDateTime(session.startTime)} - ${Utils.formatDateTime(session.endTime!)}'
                      : Utils.formatDateTime(session.startTime),
            ),
            _InfoRow(
              icon: Icons.repeat,
              label: 'Progress',
              value:
                  'Period ${session.currentPeriod} of ${session.totalSessions}',
            ),
            _InfoRow(
              icon: Icons.percent,
              label: 'Pass Threshold',
              value: '${(session.passThreshold * 100).toStringAsFixed(1)}%',
            ),

            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.play_arrow, size: 18),
                    label: Text('Reactivate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed:
                        onActivate != null ? () => onActivate!(session) : null,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.info_outline, size: 18),
                  label: Text('Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      onShowDetails != null
                          ? () => onShowDetails!(session)
                          : null,
                ),
                if (onDelete != null) ...[
                  SizedBox(width: 8),
                  ElevatedButton(
                    child: Icon(Icons.delete, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size(44, 44),
                    ),
                    onPressed: () => onDelete!(session),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
