import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/course.dart';

class CourseAttendanceDetailScreen extends StatefulWidget {
  final Course course;
  final List<Session> sessions;
  final List<String> studentIds;

  const CourseAttendanceDetailScreen({
    super.key,
    required this.course,
    required this.sessions,
    required this.studentIds,
  });

  @override
  State<CourseAttendanceDetailScreen> createState() =>
      _CourseAttendanceDetailScreenState();
}

class _CourseAttendanceDetailScreenState
    extends State<CourseAttendanceDetailScreen> {
  bool _isLoading = false;
  String? _error;
  int _currentPage = 0;
  static const int pageSize = 20;

  // Local state for fetched data
  List<User> _enrolledStudents = [];
  List<AttendanceRecord> _attendanceRecords = [];
  Course? _actualCourseDetails;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);

      if (widget.sessions.isEmpty) {
        throw Exception('No sessions provided');
      }

      final session = widget.sessions.first; // Only one session per course

      debugPrint('=== DEBUG: Fetching Attendance Data ===');
      debugPrint('Course ID: ${widget.course.id}');
      debugPrint('Session ID: ${session.id}');
      debugPrint('Current Period: ${session.currentPeriod}');

      // Fetch actual course details using the same method as manage_attendance_screen
      Course? actualCourse;
      try {
        actualCourse = await appProvider.coreServices.getCourse(
          widget.course.id,
        );
        if (actualCourse != null) {
          debugPrint(
            'Fetched actual course: Code=${actualCourse.code}, Name=${actualCourse.name}',
          );
        } else {
          debugPrint('No course found for ID ${widget.course.id}');
        }
      } catch (e) {
        debugPrint('Error fetching course details: $e');
      }

      // Fetch enrolled students for the course (through program relationships)
      final enrolledStudents = await appProvider.coreServices.getCourseStudents(
        widget.course.id,
      );

      debugPrint('Enrolled students fetched: ${enrolledStudents.length}');

      // Fetch attendance records for the session (all periods)
      final attendanceRecords = await appProvider.coreServices
          .getLecturerSessionAttendance(session.id);

      debugPrint('Attendance records fetched: ${attendanceRecords.length}');

      setState(() {
        _enrolledStudents = enrolledStudents;
        _attendanceRecords = attendanceRecords;
        _actualCourseDetails = actualCourse;
      });
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      setState(() {
        _error = 'Failed to load attendance: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local data instead of AppProvider's global state
    final students = _enrolledStudents;
    final session = widget.sessions.isNotEmpty ? widget.sessions.first : null;
    final int maxPeriods =
        session?.currentPeriod ?? 0; // Show only conducted periods
    final attendanceRecords = _attendanceRecords;

    debugPrint('=== DEBUG: Build Method ===');
    debugPrint('Students to display: ${students.length}');
    debugPrint('Max periods to show: $maxPeriods');
    debugPrint('Attendance records available: ${attendanceRecords.length}');

    // Debug student IDs and attendance record user IDs
    if (students.isNotEmpty) {
      debugPrint('Student IDs: ${students.map((s) => s.id).toList()}');
    }
    if (attendanceRecords.isNotEmpty) {
      debugPrint(
        'Attendance record user IDs: ${attendanceRecords.map((r) => r.userId).toSet().toList()}',
      );
      debugPrint(
        'Attendance records details: ${attendanceRecords.map((r) => 'User:${r.userId}, Period:${r.period}').toList()}',
      );
    }

    final int totalPages =
        students.isNotEmpty ? (students.length / pageSize).ceil() : 1;
    final int startIndex = _currentPage * pageSize;
    final int endIndex =
        (_currentPage + 1) * pageSize.clamp(0, students.length);
    final pageStudents =
        students.isNotEmpty ? students.sublist(startIndex, endIndex) : <User>[];

    bool? getAttendance(String studentId, int period) {
      // Use session.currentPeriod to determine if period has been conducted
      final currentPeriod = session?.currentPeriod ?? 0;

      if (period > currentPeriod) {
        // Period hasn't been conducted yet
        debugPrint(
          'Period $period hasn\'t been conducted yet (current: $currentPeriod)',
        );
        return null; // Period not conducted
      }

      // Period has been conducted, check if student attended
      try {
        attendanceRecords.firstWhere(
          (r) => r.userId == studentId && r.period == period,
        );
        debugPrint(
          'Found attendance: Student $studentId, Period $period - Present',
        );
        return true; // Student was present
      } catch (e) {
        // Period was conducted but student didn't attend
        debugPrint('Student $studentId was absent for period $period');
        return false; // Student was absent
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Attendance for ${_getAppBarCourseCode()}')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              )
              : students.isEmpty
              ? const Center(
                child: Text(
                  'No students enrolled in this course yet.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : maxPeriods == 0
              ? const Center(
                child: Text(
                  'No attendance periods have been conducted yet.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : Column(
                children: [
                  // Summary section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Course: ${_getCourseDisplayText()}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('Enrolled Students: ${students.length}'),
                            Text('Periods Conducted: $maxPeriods'),
                            Text('Total Records: ${attendanceRecords.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _fetchAttendance,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width:
                              300 +
                              maxPeriods *
                                  60, // Reduced width per column to match smaller cells
                          child: DataTable(
                            columnSpacing: 12, // Reduced column spacing
                            horizontalMargin: 8, // Reduced horizontal margin
                            columns: [
                              const DataColumn(label: Text('Matric No')),
                              const DataColumn(label: Text('Full Name')),
                              for (int p = 1; p <= maxPeriods; p++)
                                DataColumn(
                                  label: Text('P$p'), // Shorter column headers
                                ),
                            ],
                            rows: [
                              for (final student in pageStudents)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(student.universityId ?? student.id),
                                    ),
                                    DataCell(Text(student.name)),
                                    for (int p = 1; p <= maxPeriods; p++)
                                      DataCell(
                                        _buildAttendanceCell(
                                          getAttendance(student.id, p),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (students.isNotEmpty && totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed:
                                _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                          ),
                          Text('Page ${_currentPage + 1} of $totalPages'),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed:
                                _currentPage < totalPages - 1
                                    ? () => setState(() => _currentPage++)
                                    : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _buildAttendanceCell(bool? isPresent) {
    if (isPresent == null) {
      return const SizedBox(
        width: 40,
        height: 32,
        child: Center(
          child: Text('-', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }
    if (isPresent) {
      return const SizedBox(
        width: 40,
        height: 32,
        child: Center(child: Icon(Icons.check, color: Colors.green, size: 20)),
      );
    }
    return const SizedBox(
      width: 40,
      height: 32,
      child: Center(child: Icon(Icons.close, color: Colors.red, size: 20)),
    );
  }

  String _getCourseDisplayText() {
    debugPrint(
      'Course data - Code: "${widget.course.code}", Name: "${widget.course.name}"',
    );

    // Use actual course details if available (same approach as manage_attendance_screen)
    if (_actualCourseDetails != null) {
      debugPrint(
        'Using actual course details - Code: "${_actualCourseDetails!.code}", Name: "${_actualCourseDetails!.name}"',
      );
      return '${_actualCourseDetails!.code} - ${_actualCourseDetails!.name}';
    }

    // Fallback to widget.course data if actual details aren't available
    if (widget.course.code.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(widget.course.code)) {
      return '${widget.course.code} - ${widget.course.name}';
    }

    // If the course name already contains the code (pattern: "CODE - Name")
    if (widget.course.name.contains(' - ')) {
      return widget.course.name;
    }

    // Fallback: just use the name if code is just an ID
    return widget.course.name;
  }

  String _getAppBarCourseCode() {
    // Use actual course details if available
    if (_actualCourseDetails != null) {
      return _actualCourseDetails!.code;
    }

    // Fallback to widget.course data if actual details aren't available
    if (widget.course.code.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(widget.course.code)) {
      return widget.course.code;
    }

    // If the course name contains the code pattern "CODE - Name", extract the code
    if (widget.course.name.contains(' - ')) {
      final parts = widget.course.name.split(' - ');
      if (parts.isNotEmpty) {
        return parts[0]; // Return the course code part
      }
    }

    // Last fallback: use the course ID
    return widget.course.id;
  }
}
