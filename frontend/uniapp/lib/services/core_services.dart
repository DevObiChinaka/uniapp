import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/app_constants.dart';
import '../models/models.dart';
import '../models/course.dart';

class CoreServices {
  /// Fetch attendance records for a session (lecturer endpoint)
  Future<List<AttendanceRecord>> getLecturerSessionAttendance(
    String sessionId,
  ) async {
    try {
      final response = await _dio.get(
        '/lecturer/session/$sessionId/attendance/',
      );
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['attendance_records'] != null) {
        final List<dynamic> data = response.data['attendance_records'];
        debugPrint(
          '[getLecturerSessionAttendance] Records: ' + data.length.toString(),
        );
        return data.map((json) => AttendanceRecord.fromJson(json)).toList();
      }
      debugPrint(
        '[getLecturerSessionAttendance] Unexpected response: ${response.statusCode} - ${response.data}',
      );
      return [];
    } on DioException catch (e) {
      _handleApiError(e, 'Get lecturer session attendance');
      return [];
    }
  }

  /// Fetch a course by its ID
  Future<Course?> getCourse(String courseId) async {
    // Validate courseId to prevent malformed URLs
    if (courseId.isEmpty || courseId.trim().isEmpty) {
      debugPrint('getCourse: Empty courseId provided, returning null');
      return null;
    }

    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/courses/$courseId/',
      );
      if (response.statusCode == 200 && response.data != null) {
        return Course.fromJson(response.data);
      }
      debugPrint(
        'getCourse: Unexpected response: ${response.statusCode} - ${response.data}',
      );
      return null;
    } catch (e) {
      debugPrint('getCourse error: $e');
      return null;
    }
  }

  /// Fetch enrolled students for a course (lecturer endpoint)
  Future<List<User>> getCourseStudents(String courseId) async {
    try {
      final response = await _dio.get('/lecturer/course/$courseId/students/');
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['students'] != null) {
        final List<dynamic> data = response.data['students'];
        debugPrint(
          '[getCourseStudents] Students: ${data.length} for course $courseId',
        );
        return data.map((json) => User.fromJson(json)).toList();
      }
      debugPrint(
        '[getCourseStudents] Unexpected response: ${response.statusCode} - ${response.data}',
      );
      return [];
    } on DioException catch (e) {
      _handleApiError(e, 'Get course students');
      return [];
    }
  }

  /// Delete a session by ID
  Future<bool> deleteSession(String sessionId) async {
    try {
      String base = AppConstants.sessionEndpoint;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      final url = '$base/$sessionId/';
      final response = await _dio.delete(url);
      debugPrint(
        'DELETE SESSION: Response status: \'${response.statusCode}\', data: \'${response.data}\'',
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('DELETE SESSION: DioException: ' + e.toString());
      _handleApiError(e, 'Session deletion');
      return false;
    }
  }

  // BLE service removed
  Future<bool> activateSession(
    String sessionId, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      String base = AppConstants.sessionEndpoint;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      final url = '$base/$sessionId/activate/';
      debugPrint(
        'ACTIVATE SESSION: Sending POST to: ' +
            url +
            ' with sessionId: ' +
            sessionId +
            (latitude != null && longitude != null
                ? ', lat: $latitude, lng: $longitude'
                : ''),
      );
      final response = await _dio.post(
        url,
        data: {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      debugPrint(
        'ACTIVATE SESSION: Response status: \'${response.statusCode}\', data: \'${response.data}\'',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('ACTIVATE SESSION: DioException: ' + e.toString());
      _handleApiError(e, 'Session activation');
      return false;
    }
  }

  /// Fetch the latest profile data for the current user from /api/my-profile/
  Future<User?> fetchProfile() async {
    try {
      final response = await _dio.get(
        '${AppConstants.userEndpoint}/my-profile/',
      );
      debugPrint(
        'Fetch profile response: \\${response.statusCode} - \\${response.data}',
      );
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint(
        'Fetch profile error: \\${e.response?.statusCode} - \\${e.response?.data}',
      );
      _handleApiError(e, 'Fetch profile');
      return null;
    }
  }

  // Public getter for Dio instance (for advanced use, e.g., profile fetch)
  Dio get dio => _dio;
  final Dio _dio = Dio();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final MobileScannerController _qrController = MobileScannerController();
  // BLE fields removed

  // API Configuration
  final String _baseUrl = AppConstants.baseUrl;

  CoreServices() {
    // Configure Dio
    _dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) async {
          // Handle specific error codes
          if (e.response?.statusCode == 401) {
            // Token expired, refresh and retry
            final newToken = await _refreshToken();
            if (newToken != null) {
              e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              return handler.resolve(await _dio.fetch(e.requestOptions));
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> initialize() async {
    // Initialize FCM
    await _setupFcm();
  }

  // FCM Methods
  Future<void> _setupFcm() async {
    // Request permissions
    await _fcm.requestPermission();

    // Don't register token immediately - wait until user logs in
    // The token will be registered in the login flow

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(handlePushNotification);

    // Background messages are handled in main.dart
    // FirebaseMessaging.onBackgroundMessage is set up there
  }

  Future<void> registerFcmToken(String token) async {
    try {
      debugPrint('Registering FCM token: $token'); // <-- LOGGING
      final response = await _dio.post(
        AppConstants.fcmEndpoint,
        data: {'token': token},
      );
      debugPrint(
        'FCM registration response: \nStatus: \\${response.statusCode}\\nData: \\${response.data}',
      ); // <-- LOGGING
    } catch (e) {
      debugPrint('FCM registration error: $e');
    }
  }

  void handlePushNotification(RemoteMessage message) {
    // Parse notification and update app state
    final notification = AppNotification(
      id: '', // Provide a dummy id for now
      type: message.data['type'] ?? 'general',
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      timestamp: DateTime.now(),
    );
    // This would typically be handled via provider
    // For now, we'll just log it
    debugPrint('Received notification: [1m[0m${notification.title}');
  }

  // QR Methods
  String generateQrPayload() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hmac = _generateHmac(timestamp.toString());
    final payload = {'t': timestamp, 's': hmac};
    return jsonEncode(payload);
  }

  String _generateHmac(String data) {
    final key = utf8.encode(AppConstants.hmacSecretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  Future<bool> validateQrPayload(String qrData) async {
    try {
      final payload = jsonDecode(qrData) as Map<String, dynamic>;
      final timestamp = payload['t'] as int;
      final receivedSignature = payload['s'] as String;

      // Validate TTL
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > AppConstants.qrTtlSeconds * 1000) {
        return false;
      }

      // Validate HMAC
      final expectedSignature = _generateHmac(timestamp.toString());
      return expectedSignature == receivedSignature;
    } catch (e) {
      debugPrint('QR validation error: $e');
      return false;
    }
  }

  MobileScannerController get qrScannerController => _qrController;

  Widget buildQrView() {
    return MobileScanner(
      controller: _qrController,
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        if (barcodes.isNotEmpty) {
          final barcode = barcodes.first;
          if (barcode.rawValue != null) {
            debugPrint('QR detected: ${barcode.rawValue}');
          }
        }
      },
    );
  }

  // API Methods
  Future<bool> markAttendance({
    required String userId,
    required String sessionId,
    required bool faceVerified,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = {
        'user': int.tryParse(userId) ?? userId,
        'session': sessionId,
        'face_verified': faceVerified,
        'method': 'location',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
      debugPrint('[markAttendance] Sending payload: ' + payload.toString());
      final response = await _dio.post(
        AppConstants.attendanceEndpoint,
        data: payload,
      );
      debugPrint(
        '[markAttendance] Response status: ' + response.statusCode.toString(),
      );
      debugPrint('[markAttendance] Response data: ' + response.data.toString());
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      _handleApiError(e, 'Attendance marking');
      return false;
    }
  }

  Future<bool> createSession(Session session) async {
    try {
      final response = await _dio.post(
        AppConstants.sessionEndpoint,
        data: session.toJson(),
      );

      return response.statusCode == 201;
    } on DioException catch (e) {
      _handleApiError(e, 'Session creation');
      return false;
    }
  }

  Future<bool> endSession(String sessionId) async {
    try {
      final url = '${AppConstants.sessionEndpoint}$sessionId/end/';
      debugPrint(
        'END SESSION: Sending POST to: ' +
            url +
            ' with sessionId: ' +
            sessionId,
      );
      final response = await _dio.post(url);
      debugPrint(
        'END SESSION: Response status: \'${response.statusCode}\', data: \'${response.data}\'',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('END SESSION: DioException: ' + e.toString());
      _handleApiError(e, 'Session ending');
      return false;
    }
  }

  Future<List<Session>> getSessions(
    String userId, {
    required bool isStudent,
  }) async {
    try {
      Map<String, dynamic>? queryParams;
      if (!isStudent) {
        queryParams = {'username': userId};
      }
      final response = await _dio.get(
        AppConstants.sessionEndpoint,
        queryParameters: queryParams,
      );

      return (response.data as List)
          .map((json) => Session.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get sessions');
      return [];
    }
  }

  Future<bool> submitLeaveRequest(LeaveRequest leave) async {
    try {
      final response = await _dio.post(
        AppConstants.leaveEndpoint,
        data: leave.toJson(),
      );

      return response.statusCode == 201;
    } on DioException catch (e) {
      _handleApiError(e, 'Leave submission');
      return false;
    }
  }

  Future<List<LeaveRequest>> getLeaveRequests(String userId) async {
    try {
      final response = await _dio.get(
        AppConstants.leaveEndpoint,
        queryParameters: {'user_id': userId},
      );

      return (response.data as List)
          .map((json) => LeaveRequest.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get leave requests');
      return [];
    }
  }

  Future<ExitResult> processExit({
    required String userId,
    required String faceId,
    required String qrData,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.exitEndpoint}process/', // ✅ Fixed: correct endpoint
        data: {
          'qr_data': qrData, // ✅ OK: matches backend
          'face_image': faceId, // ✅ Fixed: face_image instead of face_id
          // Note: user comes from authentication, no need to send user_id
        },
      );

      return ExitResult.fromJson(response.data);
    } on DioException catch (e) {
      return ExitResult(
        allowed: false,
        message: _getErrorMessage(e, 'Exit processing'),
      );
    }
  }

  Future<ExitResult> processStudentExit({
    required String studentId,
    required String action,
    String? leaveId,
    String? purpose,
    String? exitDate,
    String? returnDate,
    String? qrCodeData,
  }) async {
    try {
      debugPrint('processStudentExit: studentId=$studentId, action=$action');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/security/student/process/',
        data: {
          'student_id': studentId,
          'action': action,
          'leave_id': leaveId,
          'purpose': purpose,
          'exit_date': exitDate,
          'return_date': returnDate,
          'qr_code_data': qrCodeData,
        },
      );

      debugPrint('processStudentExit response: ${response.statusCode}');
      debugPrint('processStudentExit data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        // Check if response has expected structure
        if (data == null) {
          debugPrint('processStudentExit: Response data is null');
          return ExitResult(
            allowed: false,
            message: 'Invalid response from server',
          );
        }

        // Handle both old detailed format and new simple format
        if (data['student'] != null) {
          // Detailed response format
          final student = data['student'];
          final studentName = student['name']?.toString() ?? 'Unknown';
          final universityId = student['university_id']?.toString() ?? '';
          final campusStatus = student['campus_status']?.toString() ?? '';
          final processedBy = data['processed_by']?.toString() ?? '';
          final timestamp = data['timestamp']?.toString() ?? '';

          return ExitResult(
            allowed: true,
            message:
                'Student $studentName ($universityId) has been processed for $action.\n'
                'Campus Status: $campusStatus\n'
                'Processed by: $processedBy\n'
                'Time: $timestamp',
            studentName: studentName,
          );
        } else {
          // Simple response format - just use the message
          final message =
              data['message']?.toString() ?? 'Student processed successfully';

          return ExitResult(
            allowed: true,
            message: message,
            studentName:
                'Student', // Generic name since backend doesn't provide it
          );
        }
      } else {
        debugPrint(
          'processStudentExit: Non-200 status code: ${response.statusCode}',
        );
        return ExitResult(
          allowed: false,
          message:
              'Failed to process student $action (Status: ${response.statusCode})',
        );
      }
    } on DioException catch (e) {
      debugPrint('processStudentExit DioException: ${e.toString()}');
      debugPrint(
        'processStudentExit error response: ${e.response?.statusCode} - ${e.response?.data}',
      );

      String errorMessage = 'Error processing student $action';

      if (e.response?.data != null &&
          e.response!.data is Map<String, dynamic>) {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['error'] != null) {
          errorMessage = errorData['error'].toString();
        }
      }

      return ExitResult(allowed: false, message: errorMessage);
    } catch (e) {
      debugPrint('processStudentExit general exception: ${e.toString()}');
      return ExitResult(
        allowed: false,
        message: 'Unexpected error processing student $action',
      );
    }
  }

  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: {'user_id': userId},
      );

      return (response.data as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get notifications');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getAttendanceRecords(String userId) async {
    try {
      final response = await _dio.get(
        AppConstants.attendanceEndpoint,
        queryParameters: {'user_id': userId},
      );
      return (response.data as List)
          .map((json) => AttendanceRecord.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get attendance records');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getSessionAttendance(String sessionId) async {
    try {
      final response = await _dio.get(
        AppConstants.attendanceEndpoint,
        queryParameters: {'session_id': sessionId},
      );
      return (response.data as List)
          .map((json) => AttendanceRecord.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get session attendance');
      return [];
    }
  }

  // Manual Attendance Methods
  Future<bool> markManualAttendance({
    required List<String> studentIds,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.attendanceEndpoint}manual/', // ✅ Fixed: proper endpoint format
        data: {
          'student_ids': studentIds,
          'session': sessionId, // ✅ Fixed: session instead of session_id
          'method': 'manual',
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleApiError(e, 'Manual attendance marking');
      return false;
    }
  }

  Future<bool> removeAttendanceRecord(String recordId) async {
    try {
      final response = await _dio.delete(
        '${AppConstants.attendanceEndpoint}/$recordId',
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleApiError(e, 'Remove attendance');
      return false;
    }
  }

  // Admin management methods
  Future<List<User>> fetchAllStudents() async {
    try {
      final response = await _dio.get('/admin/students/');
      debugPrint('Students API response: ${response.statusCode}');
      debugPrint('Students API data: ${response.data}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        debugPrint('Students data count: ${data.length}');

        final students =
            data.map((json) {
              debugPrint('Parsing student: $json');
              return User.fromJson(json);
            }).toList();

        debugPrint('Parsed ${students.length} students successfully');
        return students;
      }
      throw Exception('Failed to fetch students');
    } catch (e) {
      debugPrint('Error fetching students: $e');
      return [];
    }
  }

  Future<List<LeaveRequest>> fetchAllLeaveRequests() async {
    try {
      final response = await _dio.get('/admin/leave-requests/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => LeaveRequest.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch leave requests');
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
      return [];
    }
  }

  Future<List<SystemLog>> fetchSystemLogs() async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/admin/system-logs/',
      );
      debugPrint(
        'Fetch system logs response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        debugPrint('System logs data: $data');
        return data.map((json) => SystemLog.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch system logs');
    } catch (e) {
      debugPrint('Error fetching system logs: $e');
      return [];
    }
  }

  Future<void> updateStudentCampusTag(String studentId, bool isOnCampus) async {
    try {
      final response = await _dio.put(
        '/admin/students/$studentId/campus-tag/',
        data: {'is_on_campus': isOnCampus},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update campus tag');
      }
    } catch (e) {
      debugPrint('Error updating campus tag: $e');
      rethrow;
    }
  }

  Future<void> updateLeaveRequestStatus(
    String leaveRequestId,
    LeaveRequestStatus status,
  ) async {
    try {
      final response = await _dio.put(
        '/admin/leave-requests/$leaveRequestId/',
        data: {'status': status.value},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update leave request status');
      }
    } catch (e) {
      debugPrint('Error updating leave request status: $e');
      rethrow;
    }
  }

  // Utility Methods
  void _handleApiError(DioException e, String operation) {
    debugPrint('$operation error: ${e.message}');
    if (e.response != null) {
      debugPrint('Status: ${e.response!.statusCode}');
      debugPrint('Data: ${e.response!.data}');
    }
  }

  String _getErrorMessage(DioException e, String context) {
    if (e.response != null) {
      return e.response!.data['error'] ?? '$context failed';
    }
    return e.message ?? '$context failed';
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Check if token exists and is not expired
      if (token != null) {
        // Check if token is expired
        final tokenData = parseJwt(token);
        final expiryTimestamp = tokenData['exp'] as int?;

        if (expiryTimestamp != null) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(
            expiryTimestamp * 1000,
          );
          if (DateTime.now().isBefore(expiry)) {
            return token;
          }
        }

        // Token is expired, try to refresh it
        return await _refreshToken();
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving token: $e');
      return null;
    }
  }

  Future<String?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh');

      if (refreshToken == null) {
        return null;
      }

      final response = await _dio.post(
        '/auth/token/refresh/', // Corrected endpoint
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200 && response.data['access'] != null) {
        final newToken = response.data['access'] as String;
        await prefs.setString('token', newToken);
        return newToken;
      }

      return null;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return null;
    }
  }

  Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return {};
    }

    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    var resp = utf8.decode(base64Url.decode(normalized));
    final payloadMap = jsonDecode(resp);
    if (payloadMap is Map<String, dynamic>) {
      return payloadMap;
    }

    return {};
  }

  void dispose() {
    // BLE scan controller removed
    _qrController.dispose();
  }

  Future<List<User>> getAllStudents() async {
    try {
      final response = await _dio.get(AppConstants.adminStudentsEndpoint);
      return (response.data as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get all students');
      return [];
    }
  }

  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    try {
      final response = await _dio.get(AppConstants.adminLeaveEndpoint);
      return (response.data as List)
          .map((json) => LeaveRequest.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get all leave requests');
      return [];
    }
  }

  Future<List<SystemLog>> getSystemLogs() async {
    try {
      final response = await _dio.get(AppConstants.adminLogsEndpoint);
      return (response.data as List)
          .map((json) => SystemLog.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get system logs');
      return [];
    }
  }

  Future<List<ExitLog>> getExitHistory([String? userId]) async {
    try {
      Map<String, dynamic>? queryParams;
      if (userId != null) {
        queryParams = {'user_id': userId};
      }

      final response = await _dio.get(
        AppConstants.exitReportEndpoint,
        queryParameters: queryParams,
      );

      debugPrint('Exit history response: ${response.statusCode}');
      debugPrint('Exit history data: ${response.data}');

      return (response.data as List)
          .map((json) => ExitLog.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get exit history');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getAttendanceHistory([String? userId]) async {
    try {
      Map<String, dynamic>? queryParams;
      if (userId != null) {
        queryParams = {'user_id': userId};
      }

      final response = await _dio.get(
        AppConstants.attendanceReportEndpoint,
        queryParameters: queryParams,
      );

      return (response.data as List)
          .map((json) => AttendanceRecord.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _handleApiError(e, 'Get attendance history');
      return [];
    }
  }

  Future<bool> updateCampusTag(String userId, bool isOnCampus) async {
    try {
      final response = await _dio.put(
        '${AppConstants.adminStudentsEndpoint}/$userId/campus-tag/',
        data: {'is_on_campus': isOnCampus},
      );
      debugPrint(
        'Update campus tag response: ${response.statusCode} - ${response.data}',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint(
        'Update campus tag error: ${e.response?.statusCode} - ${e.response?.data}',
      );
      _handleApiError(e, 'Update campus tag');
      return false;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put(
        '${AppConstants.userEndpoint}/my-profile/',
        data: profileData,
      );
      debugPrint(
        'Update profile response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
        );
      }
    } on DioException catch (e) {
      debugPrint(
        'Update profile error: ${e.response?.statusCode} - ${e.response?.data}',
      );
      _handleApiError(e, 'Update profile');
      rethrow;
    }
  }

  Future<bool> updateLeaveStatus(
    String leaveId,
    String status,
    String? comments,
  ) async {
    try {
      final response = await _dio.put(
        '${AppConstants.adminLeaveEndpoint}/$leaveId/',
        data: {'status': status, 'comments': comments},
      );
      debugPrint(
        'Update leave status response: ${response.statusCode} - ${response.data}',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint(
        'Update leave status error: ${e.response?.statusCode} - ${e.response?.data}',
      );
      _handleApiError(e, 'Update leave status');
      return false;
    }
  }

  Future<bool> markQRAttendance({
    required String userId,
    required String sessionId,
    required bool faceVerified,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.attendanceEndpoint,
        data: {
          'user': userId, // ✅ Fixed: user instead of user_id
          'session': sessionId, // ✅ Fixed: session instead of session_id
          'face_verified': faceVerified,
          'method': 'qr',
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleApiError(e, 'QR Attendance marking');
      return false;
    }
  }

  Future<ExitResult> requestEmergencyExit({
    required String userId,
    required String reason,
  }) async {
    try {
      // Generate emergency QR data
      final emergencyQrData = jsonEncode({
        'type': 'EMERGENCY_EXIT',
        'userId': userId,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final response = await _dio.post(
        '${AppConstants.exitEndpoint}process/', // ✅ Fixed: use existing endpoint
        data: {
          'qr_data': emergencyQrData, // ✅ Fixed: proper QR data format
          'face_image': 'emergency_bypass', // ✅ Fixed: field name
          // Note: Emergency flag embedded in QR data
        },
      );

      if (response.statusCode == 200) {
        return ExitResult(
          allowed: response.data['allowed'] as bool,
          message: response.data['message'] as String,
          studentName: response.data['student_name'] as String?,
        );
      } else {
        return ExitResult(
          allowed: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final errorMsg = _getErrorMessage(e, 'Emergency exit');
      return ExitResult(allowed: false, message: errorMsg);
    }
  }

  // Logout Method
  Future<bool> logout() async {
    try {
      // Get the token
      final token = await _getAuthToken();
      final prefs = await SharedPreferences.getInstance();
      // Remove tokens from storage
      await prefs.remove('token');
      await prefs.remove('refresh');

      if (token == null) {
        // Already logged out
        return true;
      }

      // Notify the server about logout
      try {
        await _dio.post('/auth/logout/', data: {'token': token});
      } catch (e) {
        // Even if server logout fails, continue with local logout
        debugPrint('Server logout request error: $e');
      }

      // Remove FCM token registration
      final fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        try {
          await _dio.delete(
            AppConstants.fcmEndpoint,
            data: {'token': fcmToken},
          );
        } catch (e) {
          // Ignore errors removing FCM token
          debugPrint('FCM token removal error: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Logout error: $e');
      return false;
    }
  }

  // ===============================
  // SECURITY DASHBOARD METHODS
  // ===============================

  /// Generate security QR code for student campus sign-in
  Future<Map<String, dynamic>> generateSecurityQr() async {
    try {
      final response = await _dio.post('/security/qr/generate/');

      debugPrint('Security QR generation response: ${response.statusCode}');
      return {
        'success': true,
        'qr_data': response.data['qr_data'],
        'generated_at': response.data['generated_at'],
        'valid_until': response.data['valid_until'],
        'generated_by': response.data['generated_by'],
      };
    } on DioException catch (e) {
      debugPrint('Security QR generation error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e, 'Security QR generation'),
      };
    }
  }

  /// Process student return to campus via security QR scan
  Future<ExitResult> processStudentReturn(
    String securityQrData,
    String studentId,
  ) async {
    try {
      final response = await _dio.post(
        '/security/student/process/',
        data: {'student_id': studentId, 'action': 'return'},
      );

      return ExitResult(
        allowed: response.data['status'] == 'success',
        message: response.data['message'] ?? 'Student processed successfully',
        studentName: response.data['student_name'],
        studentPhotoUrl: response.data['student_photo'],
      );
    } on DioException catch (e) {
      return ExitResult(
        allowed: false,
        message: _getErrorMessage(e, 'Student return processing'),
      );
    }
  }

  /// Update student campus status (used by security)
  Future<bool> updateStudentCampusStatus(
    String studentId,
    bool isOnCampus,
  ) async {
    try {
      final response = await _dio.post(
        '/security/campus/update/',
        data: {'student_id': studentId, 'is_on_campus': isOnCampus},
      );

      debugPrint('Campus status update response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Campus status update error: $e');
      return false;
    }
  }

  /// Get security dashboard statistics
  Future<Map<String, dynamic>> getSecurityStats() async {
    try {
      final response = await _dio.get('/security/stats/');
      return response.data;
    } on DioException catch (e) {
      debugPrint('Error getting security stats: $e');
      return {'students_on_campus': 0, 'today_exits': 0, 'today_returns': 0};
    }
  }

  /// Get today's exit logs
  Future<List<Map<String, dynamic>>> getTodayExitLogs() async {
    try {
      final response = await _dio.get('/security/exit-logs/today/');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      debugPrint('Error getting today exit logs: $e');
      return [];
    }
  }

  /// Get security logs (exits, returns, system events)
  Future<List<Map<String, dynamic>>> getSecurityLogs({
    String? date,
    String? type,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (date != null) queryParams['date'] = date;
      if (type != null) queryParams['type'] = type;

      final response = await _dio.get(
        '/security/logs/',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      debugPrint('Security logs response: ${response.statusCode}');
      debugPrint('Security logs data: ${response.data}');

      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      debugPrint('Error getting security logs: $e');
      return [];
    }
  }

  /// Get students on campus count
  Future<int> getStudentsOnCampusCount([User? currentUser]) async {
    try {
      debugPrint(
        'getStudentsOnCampusCount called with user: ${currentUser?.name}, role: ${currentUser?.role}',
      );
      // Use security endpoint for security users, admin endpoint for admin users
      final students = await getStudentsForRole(currentUser);
      debugPrint('getStudentsOnCampusCount got ${students.length} students');

      // Debug each student's campus status
      for (final student in students) {
        debugPrint(
          'Student ${student.universityId}: isOnCampus=${student.isOnCampus}',
        );
      }

      final onCampusCount =
          students.where((student) => student.isOnCampus == true).length;
      debugPrint('getStudentsOnCampusCount: $onCampusCount students on campus');
      return onCampusCount;
    } catch (e) {
      debugPrint('Error getting students on campus count: $e');
      return 0;
    }
  }

  /// Get students based on current user role
  Future<List<User>> getStudentsForRole([User? currentUser]) async {
    try {
      debugPrint(
        'getStudentsForRole called with user: ${currentUser?.name}, role: ${currentUser?.role}',
      );

      // Check if current user is security
      if (currentUser?.role == 'security') {
        debugPrint('Using security endpoint for security user');
        final response = await _dio.get('/security/students/');
        if (response.statusCode == 200 && response.data['data'] != null) {
          final List<dynamic> data = response.data['data'];
          return data.map((json) => User.fromJson(json)).toList();
        }
      } else {
        debugPrint(
          'User role is not security: ${currentUser?.role}, using admin endpoint',
        );
        // For non-security users, check if they have admin role before calling admin endpoint
        if (currentUser?.role == 'admin') {
          return await getAllStudents();
        } else {
          debugPrint(
            'User is neither security nor admin, returning empty list',
          );
          return [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting students for role: $e');
      return [];
    }
  }
}
