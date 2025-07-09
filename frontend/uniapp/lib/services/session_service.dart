import '../screens/app_constants.dart';
import '../screens/app_provider.dart';
import '../models/models.dart';

class SessionService {
  final AppProvider appProvider;

  SessionService(this.appProvider);

  bool hasSessionConflict(Session newSession) {
    final currentSessions = appProvider.sessions.where((s) => s.isActive);
    for (final session in currentSessions) {
      if (session.program == newSession.program) {
        final newStart = newSession.startTime;
        final newEnd = newSession.endTime ?? newStart.add(Duration(hours: 1));
        final existingStart = session.startTime;
        final existingEnd =
            session.endTime ?? existingStart.add(Duration(hours: 1));
        // Overlap if start is before existing end and end is after existing start
        if (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isValidAttendanceWindow() {
    final activeSession = appProvider.activeSession;
    if (activeSession == null) return false;

    final now = DateTime.now();
    final sessionEnd = activeSession.endTime ?? now.add(Duration(minutes: 30));

    // Allow attendance 10 minutes before and 15 minutes after official start
    final startWindow = activeSession.startTime.subtract(Duration(minutes: 10));
    final endWindow = sessionEnd.add(Duration(minutes: 15));

    return now.isAfter(startWindow) && now.isBefore(endWindow);
  }

  bool isEligibleForExit(String studentId) {
    // 1. Check campus tag
    final student = _getStudent(studentId);
    if (student?.campusTag != 'on-campus') return false;

    // 2. Check approved leave
    final now = DateTime.now();
    final approvedLeave = appProvider.leaveRequests.any(
      (leave) =>
          leave.userId == studentId &&
          leave.isApproved &&
          leave.startDate.isBefore(now) &&
          leave.endDate.isAfter(now),
    );

    return approvedLeave;
  }

  User? _getStudent(String studentId) {
    // In real implementation, this would fetch from backend
    return User(
      id: studentId,
      name: 'Student $studentId',
      role: AppConstants.studentRole,
      campusTag: 'on-campus',
    );
  }

  int calculateSessionsAttended(String studentId, String program) {
    return appProvider.attendanceRecords
        .where(
          (record) => record.userId == studentId && record.program == program,
        )
        .length;
  }

  double calculateAttendancePercentage(String studentId, String program) {
    final attended = calculateSessionsAttended(studentId, program);
    final total =
        appProvider.sessions.where((s) => s.program == program).length;

    if (total == 0) return 0.0;
    return (attended / total) * 100;
  }

  bool isBelowThreshold(String studentId, String program) {
    final percentage = calculateAttendancePercentage(studentId, program);
    final threshold =
        appProvider.sessions
            .firstWhere(
              (s) => s.program == program,
              orElse: () => Session.empty(),
            )
            .passThreshold *
        100;

    return percentage < threshold;
  }
}
