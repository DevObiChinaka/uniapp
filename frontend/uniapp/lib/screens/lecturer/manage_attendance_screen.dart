import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.file_download,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Attendance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export attendance data for:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getCourseDisplayName(courseId),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'This will generate a CSV file with attendance records for all sessions.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.download, size: 18),
                label: Text('Export CSV'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _exportAttendance(context, courseId, sessions);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Generating CSV for ${_getCourseDisplayName(courseId)}...'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Get course details
      final course = _courseDetails[courseId];
      final courseName = course?.name ?? courseId;
      final courseCode = course?.code ?? courseId;

      // Get all attendance records for this course's sessions
      final courseAttendanceRecords =
          _attendanceRecords
              .where(
                (record) =>
                    sessions.any((session) => session.id == record.sessionId),
              )
              .toList();

      // Get enrolled students for this course
      List<User> enrolledStudents = [];
      if (sessions.first.courseId?.isNotEmpty == true) {
        final actualCourseId = sessions.first.courseId!;
        enrolledStudents = _enrolledStudents[actualCourseId] ?? [];
      }

      // Generate CSV content
      final csvData = _generateCSVData(
        courseCode,
        courseName,
        sessions,
        courseAttendanceRecords,
        enrolledStudents,
      );

      // Get current timestamp for filename
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final filename = '${courseCode}_attendance_$timestamp.csv';

      // Save file to device and show options
      await _saveAndShareCSV(context, csvData, filename);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Attendance data exported successfully!\nFile: $filename',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Export failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () => _exportAttendance(context, courseId, sessions),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _generateCSVData(
    String courseCode,
    String courseName,
    List<Session> sessions,
    List<AttendanceRecord> attendanceRecords,
    List<User> enrolledStudents,
  ) {
    final buffer = StringBuffer();

    // CSV Header with course information
    buffer.writeln('Course Attendance Report');
    buffer.writeln('Course Code,${_escapeCsvField(courseCode)}');
    buffer.writeln('Course Name,${_escapeCsvField(courseName)}');
    buffer.writeln(
      'Export Date,${DateTime.now().toIso8601String().split('T')[0]}',
    );
    buffer.writeln('Total Sessions,${sessions.length}');
    buffer.writeln('Total Students,${enrolledStudents.length}');
    buffer.writeln(''); // Empty line

    // Session summary
    buffer.writeln('Session Summary');
    buffer.writeln(
      'Session ID,Status,Current Period,Total Periods,Start Time,End Time',
    );
    for (final session in sessions) {
      final startTime = session.startTime.toIso8601String().split('T')[0];
      final endTime = session.endTime?.toIso8601String().split('T')[0] ?? 'N/A';
      buffer.writeln(
        '${_escapeCsvField(session.id)},'
        '${session.isActive ? "Active" : "Inactive"},'
        '${session.currentPeriod},'
        '${session.totalSessions},'
        '${_escapeCsvField(startTime)},'
        '${_escapeCsvField(endTime)}',
      );
    }
    buffer.writeln(''); // Empty line

    // Student attendance details
    buffer.writeln('Student Attendance Details');

    // Create headers with session IDs
    final sessionHeaders = sessions
        .map((s) => 'Session_${s.id.substring(0, 8)}')
        .join(',');
    buffer.writeln(
      'Student ID,Student Name,University ID,Total Present,Attendance Rate,$sessionHeaders',
    );

    // Process each enrolled student
    for (final student in enrolledStudents) {
      final studentAttendance =
          attendanceRecords
              .where((record) => record.userId == student.id)
              .toList();

      final totalPresent = studentAttendance.length;
      final attendanceRate =
          sessions.isNotEmpty
              ? (totalPresent / sessions.length * 100).toStringAsFixed(1)
              : '0.0';

      // Build attendance row
      final attendanceRow = sessions
          .map((session) {
            final wasPresent = studentAttendance.any(
              (record) => record.sessionId == session.id,
            );
            return wasPresent ? 'Present' : 'Absent';
          })
          .join(',');

      buffer.writeln(
        '${_escapeCsvField(student.id)},'
        '${_escapeCsvField(student.name)},'
        '${_escapeCsvField(student.universityId ?? 'N/A')},'
        '$totalPresent,'
        '$attendanceRate%,'
        '$attendanceRow',
      );
    }

    // Summary statistics
    buffer.writeln(''); // Empty line
    buffer.writeln('Summary Statistics');

    final totalAttendanceRecords = attendanceRecords.length;
    final possibleAttendances = enrolledStudents.length * sessions.length;
    final overallAttendanceRate =
        possibleAttendances > 0
            ? (totalAttendanceRecords / possibleAttendances * 100)
                .toStringAsFixed(1)
            : '0.0';

    buffer.writeln('Total Attendance Records,$totalAttendanceRecords');
    buffer.writeln('Possible Attendances,$possibleAttendances');
    buffer.writeln('Overall Attendance Rate,$overallAttendanceRate%');

    // Session-wise attendance
    buffer.writeln(''); // Empty line
    buffer.writeln('Session-wise Attendance');
    buffer.writeln('Session ID,Date,Present Count,Attendance Rate');

    for (final session in sessions) {
      final sessionAttendances =
          attendanceRecords
              .where((record) => record.sessionId == session.id)
              .length;
      final sessionRate =
          enrolledStudents.isNotEmpty
              ? (sessionAttendances / enrolledStudents.length * 100)
                  .toStringAsFixed(1)
              : '0.0';
      final sessionDate = session.startTime.toIso8601String().split('T')[0];

      buffer.writeln(
        '${_escapeCsvField(session.id)},'
        '${_escapeCsvField(sessionDate)},'
        '$sessionAttendances,'
        '$sessionRate%',
      );
    }

    return buffer.toString();
  }

  String _escapeCsvField(String field) {
    // Escape CSV fields that contain commas, quotes, or newlines
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<void> _saveAndShareCSV(
    BuildContext context,
    String csvData,
    String filename,
  ) async {
    try {
      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      // Create and write the file
      final file = File(filePath);
      await file.writeAsString(csvData);

      // Show options dialog
      await _showExportSuccessDialog(context, file, filename, csvData);
    } catch (e) {
      // Fallback to preview dialog if file operations fail
      await _showCSVPreviewDialog(context, csvData, filename);
    }
  }

  Future<void> _showExportSuccessDialog(
    BuildContext context,
    File file,
    String filename,
    String csvData,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Successful',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filename,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Saved to: ${file.path}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Choose an action:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Action buttons in a grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          'Share File',
                          Icons.share,
                          Colors.blue,
                          () {
                            Navigator.of(context).pop();
                            Share.shareXFiles([
                              XFile(file.path),
                            ], text: 'Attendance report for $filename');
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          'Copy Data',
                          Icons.copy,
                          Colors.orange,
                          () {
                            Clipboard.setData(ClipboardData(text: csvData));
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('CSV data copied to clipboard!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      context,
                      'Preview Data',
                      Icons.preview,
                      Colors.green,
                      () {
                        Navigator.of(context).pop();
                        _showCSVPreviewDialog(context, csvData, filename);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Done', style: TextStyle(color: Colors.grey[600])),
              ),
            ],
          ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showCSVPreviewDialog(
    BuildContext context,
    String csvData,
    String filename,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.preview, color: Colors.blue, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CSV Preview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filename,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'CSV Preview (first 500 characters):',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 200,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        csvData.length > 500
                            ? '${csvData.substring(0, 500)}...'
                            : csvData,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange[600], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a preview only. The actual file has been saved to your device.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.copy, size: 18),
                label: Text('Copy to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvData));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CSV data copied to clipboard!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
    );
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    String courseKey,
    List<Session> sessions,
  ) {
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

    // Calculate period completion percentage (how many periods have been held)
    final periodCompletionRate =
        activeSession.totalSessions > 0
            ? (activeSession.currentPeriod / activeSession.totalSessions * 100)
            : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Get enrolled students for navigation
            List<String> studentIds = [];
            if (sessions.first.courseId?.isNotEmpty == true) {
              final courseId = sessions.first.courseId!;
              studentIds =
                  _enrolledStudents[courseId]?.map((u) => u.id).toList() ?? [];
            } else {
              // Fallback: use students from attendance records
              studentIds =
                  _attendanceRecords
                      .where((r) => sessions.any((s) => s.id == r.sessionId))
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
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.school,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCourseDisplayName(courseKey),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Level ${sessions.first.level ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            activeSession.isActive
                                ? Colors.green[50]
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              activeSession.isActive
                                  ? Colors.green
                                  : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        activeSession.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color:
                              activeSession.isActive
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        'Current Period',
                        '${activeSession.currentPeriod}/${activeSession.totalSessions}',
                        Icons.event,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        'Students',
                        studentCount.toString(),
                        Icons.people,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        'Progress',
                        '${periodCompletionRate.toStringAsFixed(1)}%',
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.visibility, size: 18),
                        label: Text('View Details'),
                        onPressed: () {
                          // Same navigation logic as card tap
                          List<String> studentIds = [];
                          if (sessions.first.courseId?.isNotEmpty == true) {
                            final courseId = sessions.first.courseId!;
                            studentIds =
                                _enrolledStudents[courseId]
                                    ?.map((u) => u.id)
                                    .toList() ??
                                [];
                          } else {
                            studentIds =
                                _attendanceRecords
                                    .where(
                                      (r) => sessions.any(
                                        (s) => s.id == r.sessionId,
                                      ),
                                    )
                                    .map((r) => r.userId)
                                    .toSet()
                                    .toList();
                          }

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
                                          id: 1,
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
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon:
                          _isExporting
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Icon(Icons.file_download, size: 18),
                      label: Text('Export'),
                      onPressed:
                          _isExporting
                              ? null
                              : () => _showExportDialog(
                                context,
                                courseKey,
                                sessions,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final currentUser = appProvider.getCurrentUser();

    Widget buildContent() {
      if (_isLoading) {
        return Center(
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
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        );
      }

      if (_errorMessage != null) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                    SizedBox(height: 16),
                    Text(
                      'Oops! Something went wrong',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Try Again'),
                      onPressed: _fetchData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (currentUser == null) {
        return Center(
          child: Card(
            margin: EdgeInsets.all(20),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: Colors.orange[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Authentication Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please log in to manage attendance',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final username = currentUser.username;
      if (username == null || username.isEmpty) {
        return Center(
          child: Card(
            margin: EdgeInsets.all(20),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.red[400]),
                  SizedBox(height: 16),
                  Text(
                    'Invalid Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'User profile is incomplete',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );
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
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: Colors.blue[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Courses Found',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You haven\'t created any sessions yet',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Create Session'),
                      onPressed: () {
                        // Navigate to configuration screen
                        Navigator.of(
                          context,
                        ).pop(); // Go back to main lecturer screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Attendance Management',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Monitor and export attendance data for your courses',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Stats section
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Courses',
                      courseSessions.length.toString(),
                      Icons.school,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Sessions',
                      lecturerSessions.length.toString(),
                      Icons.event,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Course list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final courseKey = courseSessions.keys.elementAt(index);
              final sessions = courseSessions[courseKey]!;

              return _buildCourseCard(context, courseKey, sessions);
            }, childCount: courseSessions.length),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Attendance'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isLoading ? Colors.grey : Colors.white,
            ),
            onPressed: _isLoading ? null : _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _fetchData, child: buildContent()),
    );
  }
}
