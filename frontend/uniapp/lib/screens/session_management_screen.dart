import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';
// import 'package:uniapp/screens/app_constants.dart'; // Removed unused import
import 'package:intl/intl.dart';
import 'dart:async';

class SessionManagementScreen extends StatefulWidget {
  final String lecturerId;
  final String token;

  const SessionManagementScreen({
    Key? key,
    required this.lecturerId,
    required this.token,
  }) : super(key: key);

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  bool _isLoading = true;
  List<Session> _activeSessions = [];
  List<Session> _pastSessions = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();

    // Refresh active sessions periodically
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _loadSessions();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final sessions = await appProvider.fetchLecturerSessions(
        widget.lecturerId,
      );

      setState(() {
        _activeSessions = sessions.where((s) => s.isActive).toList();
        _pastSessions = sessions.where((s) => !s.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sessions: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading sessions: $e');
    }
  }

  Future<void> _endSession(Session session) async {
    setState(() => _isLoading = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final success = await appProvider.endSession(session.id);

      if (success) {
        _showSnackBar('Session ended successfully');
        _loadSessions();
      } else {
        _showSnackBar('Failed to end session');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error ending session: $e');
      _showSnackBar('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showEndSessionDialog(Session session) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('End Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to end this session?'),
                SizedBox(height: 8),
                Text(
                  'Program: ${session.program}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Started: ${_formatDateTime(session.startTime)}'),
                SizedBox(height: 16),
                Text(
                  'Note: Students will no longer be able to mark attendance for this session.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('End Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _endSession(session);
                },
              ),
            ],
          ),
    );
  }

  Future<void> _viewSessionDetails(Session session) async {
    setState(() => _isLoading = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final attendanceStats = await appProvider.getSessionAttendanceStats(
        session.id,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Navigate to session details screen
      Navigator.pushNamed(
        context,
        '/attendance_management',
        arguments: {
          'sessionId': session.id,
          'program': session.program,
          'stats': attendanceStats,
          'isActive': session.isActive,
        },
      );
    } catch (e) {
      print('Error loading session details: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(dateTime);
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) {
      final now = DateTime.now();
      final duration = now.difference(start);
      return _formatDurationString(duration);
    } else {
      final duration = end.difference(start);
      return _formatDurationString(duration);
    }
  }

  String _formatDurationString(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Sessions'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSessions,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadSessions,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active sessions section
                      Text(
                        'Active Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      SizedBox(height: 8),

                      _activeSessions.isEmpty
                          ? _buildEmptyState('No active sessions')
                          : Column(
                            children:
                                _activeSessions
                                    .map(
                                      (session) =>
                                          _buildSessionCard(session, true),
                                    )
                                    .toList(),
                          ),

                      SizedBox(height: 24),

                      // Past sessions section
                      Text(
                        'Past Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 8),

                      _pastSessions.isEmpty
                          ? _buildEmptyState('No past sessions')
                          : Column(
                            children:
                                _pastSessions
                                    .map(
                                      (session) =>
                                          _buildSessionCard(session, false),
                                    )
                                    .toList(),
                          ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/session_configuration',
            arguments: {'lecturerId': widget.lecturerId, 'token': widget.token},
          ).then((_) => _loadSessions());
        },
        icon: Icon(Icons.add),
        label: Text('New Session'),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.grey, size: 48),
          SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session, bool isActive) {
    final startTime = session.startTime;
    final endTime = session.endTime;
    final duration = _formatDuration(startTime, endTime);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green.shade300 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.play_circle_filled : Icons.check_circle,
                  color: isActive ? Colors.green : Colors.blue.shade300,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.program,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.green,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Started: ${_formatDateTime(startTime)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (!isActive)
                        Text(
                          'Ended: ${_formatDateTime(endTime!)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      SizedBox(height: 4),
                      Text(
                        'Duration: $duration',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Session ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      session.id,
                      style: TextStyle(
                        fontFamily: 'Monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive)
                  OutlinedButton.icon(
                    icon: Icon(Icons.qr_code),
                    label: Text('QR Code'),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/qr_generation',
                        arguments: {
                          'sessionId': session.id,
                          'program': session.program,
                        },
                      );
                    },
                  ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.people),
                  label: Text('Attendance'),
                  onPressed: () => _viewSessionDetails(session),
                ),
                SizedBox(width: 8),
                if (isActive)
                  ElevatedButton.icon(
                    icon: Icon(Icons.stop),
                    label: Text('End'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showEndSessionDialog(session),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
