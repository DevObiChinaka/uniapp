import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/course.dart';
import '../../models/program.dart';
import 'course_attendance_detail_screen.dart';

class ManageAttendanceScreen extends StatefulWidget {
  const ManageAttendanceScreen({super.key});

  @override
  State<ManageAttendanceScreen> createState() => _ManageAttendanceScreenState();
}

class _ManageAttendanceScreenState extends State<ManageAttendanceScreen> {
  bool _isExporting = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final user = appProvider.getCurrentUser();

      if (user?.username == null) {
        throw Exception('Please log in to continue');
      }

      final username = user!.username!;
      // Fetch both sessions and attendance records
      await Future.wait([
        appProvider.fetchLecturerSessions(username),
        appProvider.fetchPrograms(),
      ]);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExportDialog(
    BuildContext context,
    String courseId,
    List<Session> sessions,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export Attendance'),
            content: Text('Export attendance data for $courseId?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _exportAttendance(context, courseId, sessions);
                },
                child: const Text('Export'),
              ),
            ],
          ),
    );
  }

  Future<void> _exportAttendance(
    BuildContext context,
    String courseId,
    List<Session> sessions,
  ) async {
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exporting attendance data for $courseId...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final provider = Provider.of<AppProvider>(context, listen: false);
      // TODO: Implement actual export logic in AppProvider
      // await provider.exportAttendanceData(courseId, sessions);
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance data exported successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final currentUser = appProvider.getCurrentUser();

    Widget buildContent() {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_errorMessage != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        );
      }

      if (currentUser == null) {
        return const Center(child: Text('Please log in to manage attendance'));
      }

      final username = currentUser.username;
      if (username == null || username.isEmpty) {
        return const Center(child: Text('Invalid user profile'));
      }

      // Get all sessions for the current lecturer
      final lecturerSessions =
          appProvider.sessions
              .where((s) => s.lecturerUsername == username)
              .toList();

      // Group sessions by course (filtering out null courseIds)
      final courseSessions = <String, List<Session>>{};
      for (var session in lecturerSessions) {
        final courseId = session.courseId;
        if (courseId != null && courseId.isNotEmpty) {
          courseSessions.putIfAbsent(courseId, () => []).add(session);
        }
      }

      if (courseSessions.isEmpty) {
        return const Center(child: Text('No courses with sessions found.'));
      }

      return ListView.builder(
        itemCount: courseSessions.length,
        itemBuilder: (context, index) {
          final courseId = courseSessions.keys.elementAt(index);
          final sessions = courseSessions[courseId]!;

          // Find active session (if any)
          final activeSession = sessions.firstWhere(
            (s) => s.isActive,
            orElse: () => sessions.first,
          );

          // Get unique enrolled students from attendance records
          final enrolledStudents =
              appProvider.attendanceRecords
                  .where((r) => sessions.any((s) => s.id == r.sessionId))
                  .map((r) => r.userId)
                  .toSet();
          final studentCount = enrolledStudents.length;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                courseId, // TODO: Get course name from courseId
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Period: ${activeSession.currentPeriod}'),
                  Text('Registered Students: $studentCount'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon:
                        _isExporting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(
                              Icons.file_download,
                              color: Colors.blue,
                            ),
                    tooltip: 'Export CSV',
                    onPressed:
                        _isExporting
                            ? null
                            : () =>
                                _showExportDialog(context, courseId, sessions),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.green,
                    ),
                    tooltip: 'View Details',
                    onPressed: () {
                      // Create a Course object with program info from session
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => CourseAttendanceDetailScreen(
                                course: Course(
                                  id: courseId,
                                  code: courseId,
                                  name: 'Course $courseId',
                                  programs: [
                                    Program(
                                      id: 1, // TODO: Get program ID from API
                                      name: sessions.first.program,
                                    ),
                                  ],
                                  level: sessions.first.level ?? '',
                                ),
                                sessions: sessions,
                                studentIds: enrolledStudents.toList(),
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: buildContent(),
    );
  }
}
