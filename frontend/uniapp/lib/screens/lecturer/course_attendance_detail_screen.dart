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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Attendance Details',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _fetchAttendance,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 12),
                          Text(
                            _getAppBarCourseCode(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Course Attendance Overview',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Section
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child:
                      _isLoading
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading attendance data...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : _error != null
                          ? Container(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.red[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Error Loading Data',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          _error!,
                                          style: TextStyle(
                                            color: Colors.red[600],
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _fetchAttendance,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : students.isEmpty
                          ? Container(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: Colors.blue[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No Students Enrolled',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'No students are enrolled in this course yet.',
                                          style: TextStyle(
                                            color: Colors.blue[600],
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : maxPeriods == 0
                          ? Container(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.orange[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 48,
                                          color: Colors.orange[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No Sessions Conducted',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'No attendance periods have been conducted yet.',
                                          style: TextStyle(
                                            color: Colors.orange[600],
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : Column(
                            children: [
                              // Summary Cards Section
                              Container(
                                margin: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Course Overview',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 10,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getCourseDisplayText(),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildStatCard(
                                                  icon: Icons.people,
                                                  title: 'Students',
                                                  value: '${students.length}',
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: _buildStatCard(
                                                  icon: Icons.access_time,
                                                  title: 'Periods',
                                                  value: '$maxPeriods',
                                                  color: Colors.green,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: _buildStatCard(
                                                  icon: Icons.check_circle,
                                                  title: 'Records',
                                                  value:
                                                      '${attendanceRecords.length}',
                                                  color: Colors.purple,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Attendance Table Section
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 20),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Attendance Records',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          Spacer(),
                                          if (students.isNotEmpty &&
                                              totalPages > 1)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Page ${_currentPage + 1} of $totalPages',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: _fetchAttendance,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: SingleChildScrollView(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey[300]!,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: DataTable(
                                                  columnSpacing: 16,
                                                  horizontalMargin: 16,
                                                  headingRowColor:
                                                      WidgetStateProperty.all(
                                                        Colors.grey[50],
                                                      ),
                                                  columns: [
                                                    DataColumn(
                                                      label: Text(
                                                        'Matric No',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Full Name',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                    for (
                                                      int p = 1;
                                                      p <= maxPeriods;
                                                      p++
                                                    )
                                                      DataColumn(
                                                        label: Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(
                                                                  context,
                                                                ).primaryColor
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'P$p',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Theme.of(
                                                                    context,
                                                                  ).primaryColor,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                  rows: [
                                                    for (final student
                                                        in pageStudents)
                                                      DataRow(
                                                        cells: [
                                                          DataCell(
                                                            Text(
                                                              student.universityId ??
                                                                  student.id,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color:
                                                                    Colors
                                                                        .grey[800],
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              student.name,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color:
                                                                    Colors
                                                                        .grey[800],
                                                              ),
                                                            ),
                                                          ),
                                                          for (
                                                            int p = 1;
                                                            p <= maxPeriods;
                                                            p++
                                                          )
                                                            DataCell(
                                                              _buildAttendanceCell(
                                                                getAttendance(
                                                                  student.id,
                                                                  p,
                                                                ),
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
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Pagination Section
                              if (students.isNotEmpty && totalPages > 1)
                                Container(
                                  margin: EdgeInsets.all(20),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color:
                                              _currentPage > 0
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                      .withValues(alpha: 0.1)
                                                  : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.arrow_back_ios,
                                            color:
                                                _currentPage > 0
                                                    ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                    : Colors.grey[400],
                                          ),
                                          onPressed:
                                              _currentPage > 0
                                                  ? () => setState(
                                                    () => _currentPage--,
                                                  )
                                                  : null,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${_currentPage + 1} of $totalPages',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Container(
                                        decoration: BoxDecoration(
                                          color:
                                              _currentPage < totalPages - 1
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                      .withValues(alpha: 0.1)
                                                  : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.arrow_forward_ios,
                                            color:
                                                _currentPage < totalPages - 1
                                                    ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                    : Colors.grey[400],
                                          ),
                                          onPressed:
                                              _currentPage < totalPages - 1
                                                  ? () => setState(
                                                    () => _currentPage++,
                                                  )
                                                  : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              SizedBox(height: 20),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCell(bool? isPresent) {
    if (isPresent == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            '-',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isPresent ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPresent ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Center(
        child: Icon(
          isPresent ? Icons.check_circle : Icons.cancel,
          color: isPresent ? Colors.green[600] : Colors.red[600],
          size: 20,
        ),
      ),
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
