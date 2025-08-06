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
  List<Session> _lecturerSessions = [];
  List<AttendanceRecord> _attendanceRecords = [];
  Map<String, Course> _courseDetails = {};
  Map<String, List<User>> _enrolledStudents = {};

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

      // Fetch sessions directly like LecturerSessionsScreen does
      final sessions = await appProvider.coreServices.getSessions(
        username,
        isStudent: false,
      );

      debugPrint('=== DEBUG: Direct Session Fetch ===');
      debugPrint('Total sessions fetched: ${sessions.length}');

      setState(() {
        _lecturerSessions = sessions;
      });

      // Fetch attendance records for all sessions
      final allAttendanceRecords = <AttendanceRecord>[];
      for (final session in sessions) {
        try {
          final sessionAttendance = await appProvider.coreServices
              .getLecturerSessionAttendance(session.id);
          allAttendanceRecords.addAll(sessionAttendance);
        } catch (e) {
          debugPrint('Error fetching attendance for session ${session.id}: $e');
        }
      }

      setState(() {
        _attendanceRecords = allAttendanceRecords;
      });

      debugPrint('=== DEBUG: Attendance Records ===');
      debugPrint('Total attendance records: ${_attendanceRecords.length}');

      // Fetch course details for unique courseIds
      final uniqueCourseIds =
          sessions
              .where((s) => s.courseId?.isNotEmpty == true)
              .map((s) => s.courseId!)
              .toSet();

      debugPrint('=== DEBUG: Course IDs to fetch ===');
      debugPrint('Unique course IDs: $uniqueCourseIds');

      final courseDetails = <String, Course>{};
      for (final courseId in uniqueCourseIds) {
        try {
          final course = await appProvider.coreServices.getCourse(courseId);
          if (course != null) {
            courseDetails[courseId] = course;
            debugPrint(
              'Fetched course for ID $courseId: Code=${course.code}, Name=${course.name}',
            );
          } else {
            debugPrint('No course found for ID $courseId');
          }
        } catch (e) {
          debugPrint('Error fetching course details for $courseId: $e');
        }
      }

      setState(() {
        _courseDetails = courseDetails;
      });

      debugPrint('=== DEBUG: Course Details ===');
      debugPrint('Fetched details for ${_courseDetails.length} courses');

      // Fetch enrolled students for each course
      final enrolledStudents = <String, List<User>>{};
      for (final courseId in uniqueCourseIds) {
        try {
          final students = await appProvider.coreServices.getCourseStudents(
            courseId,
          );
          enrolledStudents[courseId] = students;
        } catch (e) {
          debugPrint('Error fetching enrolled students for $courseId: $e');
        }
      }

      setState(() {
        _enrolledStudents = enrolledStudents;
      });

      debugPrint('=== DEBUG: Enrolled Students ===');
      debugPrint(
        'Fetched enrolled students for ${_enrolledStudents.length} courses',
      );
      for (final entry in _enrolledStudents.entries) {
        debugPrint(
          'Course ${entry.key}: ${entry.value.length} enrolled students',
        );
      }

      // Also fetch programs
      await appProvider.fetchPrograms();
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

  String _getCourseDisplayName(String courseKey) {
    // Check if we have course details for this courseKey
    final course = _courseDetails[courseKey];
    if (course != null) {
      // Show "CODE - Course Name" format
      return '${course.code} - ${course.name}';
    }

    // Fallback to courseKey (could be courseId or program name)
    return courseKey;
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

      // Use the sessions fetched in _fetchData
      final lecturerSessions = _lecturerSessions;

      debugPrint('=== DEBUG: Session Analysis in Build ===');
      debugPrint('Using stored sessions: ${lecturerSessions.length}');

      // Group sessions by course - use courseId if available, otherwise use program
      final courseSessions = <String, List<Session>>{};
      for (var session in lecturerSessions) {
        final courseKey =
            (session.courseId?.isNotEmpty == true)
                ? session.courseId!
                : session.program;

        if (courseKey.isNotEmpty) {
          courseSessions.putIfAbsent(courseKey, () => []).add(session);
        }
      }

      if (courseSessions.isEmpty) {
        return const Center(child: Text('No courses with sessions found.'));
      }

      return ListView.builder(
        itemCount: courseSessions.length,
        itemBuilder: (context, index) {
          final courseKey = courseSessions.keys.elementAt(index);
          final sessions = courseSessions[courseKey]!;

          // Find active session (if any)
          final activeSession = sessions.firstWhere(
            (s) => s.isActive,
            orElse: () => sessions.first,
          );

          // Get enrolled student count for this course
          int studentCount = 0;
          if (sessions.first.courseId?.isNotEmpty == true) {
            // If we have courseId, use enrolled students from course
            final courseId = sessions.first.courseId!;
            studentCount = _enrolledStudents[courseId]?.length ?? 0;
            debugPrint(
              'Using course enrollment for $courseKey (courseId: $courseId): $studentCount students',
            );
          } else {
            // Fallback: count unique students from attendance records
            final enrolledStudents =
                _attendanceRecords
                    .where((r) => sessions.any((s) => s.id == r.sessionId))
                    .map((r) => r.userId)
                    .toSet();
            studentCount = enrolledStudents.length;
            debugPrint(
              'Using attendance records for $courseKey: $studentCount students',
            );
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                // Get enrolled students for navigation
                List<String> studentIds = [];
                if (sessions.first.courseId?.isNotEmpty == true) {
                  final courseId = sessions.first.courseId!;
                  studentIds =
                      _enrolledStudents[courseId]?.map((u) => u.id).toList() ??
                      [];
                } else {
                  // Fallback: use students from attendance records
                  studentIds =
                      _attendanceRecords
                          .where(
                            (r) => sessions.any((s) => s.id == r.sessionId),
                          )
                          .map((r) => r.userId)
                          .toSet()
                          .toList();
                }

                // Create a Course object with program info from session
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => CourseAttendanceDetailScreen(
                          course: Course(
                            id: courseKey,
                            code: courseKey,
                            name: 'Course $courseKey',
                            programs: [
                              Program(
                                id: 1, // TODO: Get program ID from API
                                name: sessions.first.program,
                              ),
                            ],
                            level: sessions.first.level ?? '',
                          ),
                          sessions: sessions,
                          studentIds: studentIds,
                        ),
                  ),
                );
              },
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  _getCourseDisplayName(courseKey),
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
                trailing: IconButton(
                  icon:
                      _isExporting
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.file_download, color: Colors.blue),
                  tooltip: 'Export CSV',
                  onPressed:
                      _isExporting
                          ? null
                          : () =>
                              _showExportDialog(context, courseKey, sessions),
                ),
                isThreeLine: true,
              ),
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
