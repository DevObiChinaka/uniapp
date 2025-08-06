import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/course.dart';

class LecturerDashboard extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const LecturerDashboard({super.key, this.onProfileTap});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  Future<List<Session>>? _sessionsFuture;
  String? _lecturerUsername;
  Map<String, Course> _courseDetails = {};
  Map<String, int> _attendanceStats = {};
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    (() async {
      await appProvider.loadUserData();
      await appProvider.fetchPrograms();
      setState(() {
        _lecturerUsername =
            appProvider.getCurrentUser()?.username ?? appProvider.userId ?? '';
        _sessionsFuture = appProvider.fetchLecturerSessions(_lecturerUsername!);
      });
      _loadDashboardData();
    })();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final sessions = await _sessionsFuture!;

      // Fetch course details for unique courseIds
      final uniqueCourseIds =
          sessions
              .where((s) => s.courseId?.isNotEmpty == true)
              .map((s) => s.courseId!)
              .toSet();

      final courseDetails = <String, Course>{};
      final attendanceStats = <String, int>{};

      for (final courseId in uniqueCourseIds) {
        try {
          final course = await appProvider.coreServices.getCourse(courseId);
          if (course != null) {
            courseDetails[courseId] = course;

            // Fetch attendance records for sessions of this course
            final courseSessions = sessions.where(
              (s) => s.courseId == courseId,
            );

            int totalAttendance = 0;
            for (final session in courseSessions) {
              try {
                final attendanceRecords = await appProvider.coreServices
                    .getLecturerSessionAttendance(session.id);
                totalAttendance += attendanceRecords.length;
              } catch (e) {
                debugPrint(
                  'Error fetching attendance for session ${session.id}: $e',
                );
              }
            }
            attendanceStats[courseId] = totalAttendance;
          }
        } catch (e) {
          debugPrint('Error fetching course details for $courseId: $e');
        }
      }

      setState(() {
        _courseDetails = courseDetails;
        _attendanceStats = attendanceStats;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.loadUserData();
    await appProvider.fetchPrograms();
    setState(() {
      _lecturerUsername =
          appProvider.getCurrentUser()?.username ?? appProvider.userId ?? '';
      _sessionsFuture = appProvider.fetchLecturerSessions(_lecturerUsername!);
    });
    _loadDashboardData();
  }

  String _formatDateTime(DateTime dateTime) {
    final date = DateFormat('MMM d, yyyy').format(dateTime);
    final time = DateFormat('h:mm a').format(dateTime);
    return '$date at $time';
  }

  String _getCourseDisplayName(String courseId) {
    final course = _courseDetails[courseId];
    if (course != null) {
      // Use actual course details if available
      if (course.code.isNotEmpty && !RegExp(r'^\d+$').hasMatch(course.code)) {
        return course.code;
      }
      // If the course name contains the code pattern "CODE - Name", extract the code
      if (course.name.contains(' - ')) {
        final parts = course.name.split(' - ');
        if (parts.isNotEmpty) {
          return parts[0]; // Return the course code part
        }
      }
    }
    return 'Course $courseId';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: FutureBuilder<List<Session>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (_sessionsFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Dashboard'),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Dashboard'),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: Center(child: Text('Error loading dashboard')),
            );
          }
          final sessions = snapshot.data ?? [];
          final Session? activeSession =
              sessions.where((s) => s.isActive).isNotEmpty
                  ? sessions.firstWhere((s) => s.isActive)
                  : null;

          return Scaffold(
            appBar: AppBar(
              title: Text('Dashboard'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      widget.onProfileTap?.call();
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
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
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Colors.green[50]!, Colors.green[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.school, color: Colors.white),
                          ),
                          title: Text(
                            _getCourseDisplayName(activeSession.courseId ?? ''),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            'Started: ${_formatDateTime(activeSession.startTime)}',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Attendance Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (_isLoadingStats)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Loading attendance statistics...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_attendanceStats.isEmpty)
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
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No attendance data available yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start a session to begin tracking attendance',
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
                    Column(
                      children:
                          _attendanceStats.entries
                              .map(
                                (entry) => Card(
                                  elevation: 3,
                                  margin: EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.book,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    title: Text(
                                      _getCourseDisplayName(entry.key),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${entry.value} records',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  SizedBox(height: 24),
                  if (sessions.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Recent Sessions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      children:
                          sessions
                              .take(5)
                              .map(
                                (session) => Card(
                                  elevation: 2,
                                  margin: EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          session.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.1),
                                      child: Icon(
                                        session.isActive
                                            ? Icons.play_circle
                                            : Icons.history,
                                        color:
                                            session.isActive
                                                ? Colors.green
                                                : Colors.grey[600],
                                      ),
                                    ),
                                    title: Text(
                                      _getCourseDisplayName(
                                        session.courseId ?? '',
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatDateTime(session.startTime),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    trailing:
                                        session.isActive
                                            ? Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                                    'ACTIVE',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ] else ...[
                    SizedBox(height: 20),
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
                              Icons.event_note,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No sessions found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create your first session to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
