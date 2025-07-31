class AppConstants {
  // Role definitions
  static const String studentRole = 'student';
  static const String lecturerRole = 'lecturer';
  static const String securityRole = 'security';
  static const String adminRole = 'admin';

  // BLE Configuration
  static const String bleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String bleCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const int bleScanDuration = 10; // seconds
  static const int bleAdvertiseInterval = 100; // milliseconds
  static const int bleRssiThreshold = -80; // RSSI value for ~5-10m range

  // QR Configuration
  static const int qrTtlSeconds = 300; // Refresh every 45 seconds
  static const String hmacSecretKey =
      'a3d7b9e2a1f91bd1c21a746a14e55c4a1c2f387b3f45e2c3f74a2f816b6d5a49';

  // Debug settings
  static const bool enforceVerificationInDebug = false;

  // API Configuration
  static const String baseUrl = 'http://172.20.10.11:8000/api';
  static const String faceApiEndpoint =
      'https://facin-api-test.cognitiveservices.azure.com/';

  // API Endpoints
  static const String attendanceEndpoint = '$baseUrl/attendance/';
  // Attendance management endpoints
  static const String attendanceRemoveEndpoint =
      '$baseUrl/attendance/{id}/remove/';
  static const String attendanceFlagEndpoint = '$baseUrl/attendance/{id}/flag/';

  static const String sessionEndpoint = '$baseUrl/sessions/';
  // Session management endpoints
  static const String sessionUpdateDetailsEndpoint = '$baseUrl/sessions/{id}/update_details/';
  static const String sessionActivateEndpoint = '$baseUrl/sessions/{id}/activate/';
  static const String leaveEndpoint = '$baseUrl/leave/';
  static const String exitEndpoint = '$baseUrl/exit/';
  static const String fcmEndpoint = '$baseUrl/fcm/';
  static const String faceEndpoint = '$faceApiEndpoint/detect/';
  static const String verifyEndpoint = '$faceApiEndpoint/verify/';
  static const String userEndpoint = baseUrl;

  // Attendance Thresholds
  static const int defaultTotalSessions = 10;
  static const double defaultPassThreshold = 0.7; // 70%

  // Notification Types
  static const String notifLeaveApproved = 'leave_approved';
  static const String notifLeaveDenied = 'leave_denied';
  static const String notifSessionStart = 'session_start';
  static const String notifSessionEnd = 'session_end';
  static const String notifLowAttendance = 'low_attendance';
  static const String notifExitAllowed = 'exit_allowed';
  static const String notifExitDenied = 'exit_denied';
  static const String notifSecurityAlert = 'security_alert';

  // Face API Parameters
  static const String faceDetectionAttributes =
      'age,gender,headPose,smile,facialHair,glasses,emotion,hair,makeup,occlusion,accessories,blur,exposure,noise';
  static const bool enableLivenessCheck = true;

  // Error Messages
  static const String networkError =
      'Network unavailable. Please check your connection';
  static const String bleError = 'Bluetooth error. Ensure Bluetooth is enabled';
  static const String faceError = 'Face verification failed. Please try again';
  static const String sessionConflictError =
      'Cannot start session: Conflict with existing session';
  static const String qrExpiredError =
      'QR code expired. Please request a new one';
  static const String unauthorizedExitError =
      'Exit denied: No approved leave request found';

  static const String adminStudentsEndpoint = '$baseUrl/admin/students';
  static const String adminLeaveEndpoint = '$baseUrl/admin/leave-requests';
  static const String adminLogsEndpoint = '$baseUrl/admin/system-logs';

  // Face verification threshold
  static const double faceConfidenceThreshold = 0.7;

  // Face API Keys
  static const String faceApiKey1 =
      'FFveXtbSQaaGJWRS5Mxj93MF02EQromA5BC77OjHCdbHMxgawg0OJQQJ99BGACYeBjFXJ3w3AAAKACOGqsqC';
  static const String faceApiKey2 =
      '5DcKp6aLK3sAp4wsBPcqEgFrfP3dxecrYiNB5Gzrr12vBlWwunfMJQQJ99BGACYeBjFXJ3w3AAAKACOGjSzE';
  static const String faceApiRegion = 'eastus';

  // Offline Support
  static const String offlineAttendanceKey = 'offline_attendance';
  static const int offlineSyncInterval = 5; // minutes
  static const int maxOfflineRecords = 50;

  // Data Synchronization
  static const bool enableAutoSync = true;
  static const int syncRetryAttempts = 3;
}
