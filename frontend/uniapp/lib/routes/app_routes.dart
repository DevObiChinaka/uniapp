import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/student_dashboard.dart';
import '../screens/lecturer_dashboard.dart';
import '../screens/security_dashboard.dart';

class AppRoutes {
  // Route path names
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const biometricLogin = '/biometric_login';
  static const editProfile = '/edit_profile';
  static const forgotPassword = '/forgot_password';
  static const changePassword = '/change_password';

  // Dashboard routes
  static const studentDashboard = '/student_dashboard';
  static const lecturerDashboard = '/lecturer_dashboard';
  static const securityDashboard = '/security_dashboard';
  static const adminDashboard = '/admin_dashboard';

  // Student routes
  static const attendanceScan = '/attendance_scan';
  static const leaveSubmission = '/leave_submission';
  static const exitScan = '/exit_scan';
  static const viewAttendance = '/view_attendance';
  static const emergencyExit = '/emergency_exit';

  // Lecturer routes
  static const sessionConfiguration = '/session_configuration';
  static const sessionManagement = '/session_management';
  static const attendanceManagement = '/attendance_management';
  static const qrGeneration = '/qr_generation';
  static const attendanceReports = '/attendance_reports';

  // Security routes
  static const exitVerification = '/exit_verification';
  static const securityLogs = '/security_logs';

  // Admin routes
  static const userManagement = '/user_management';
  static const systemSettings = '/system_settings';
  static const adminReports = '/admin_reports';

  // Common routes
  static const faceVerification = '/face_verification';
  static const notifications = '/notifications';
  static const profile = '/profile';
}
