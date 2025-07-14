import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/app_constants.dart';
import '../models/models.dart';

class CoreServices {
  final Dio _dio = Dio();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final MobileScannerController _qrController = MobileScannerController();
  final FlutterReactiveBle _flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  // BLE State
  StreamController<DiscoveredDevice> _bleScanController =
      StreamController<DiscoveredDevice>.broadcast();

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

    // Get token and register
    final fcmToken = await _fcm.getToken();
    if (fcmToken != null) {
      await registerFcmToken(fcmToken);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(handlePushNotification);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    // Handle background messages
    debugPrint("Handling background message: ${message.messageId}");
  }

  // BLE Methods
  Stream<DiscoveredDevice> scanBleDevices() async* {
    // Request Bluetooth permissions before scanning
    await _ensureBluetoothPermissions();
    await for (final device in _flutterReactiveBle.scanForDevices(
      withServices: [],
    )) {
      _bleScanController.add(device);
      yield device;
    }
  }

  Future<void> stopBleScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> _ensureBluetoothPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ];
    final statuses = await permissions.request();
    if (statuses.values.any((status) => !status.isGranted)) {
      throw Exception('Bluetooth permissions denied');
    }
  }

  // RSSI should be accessed from DiscoveredDevice.rssi in flutter_reactive_ble.
  // Example usage: device.rssi
  // Removed getDeviceRssi method as it's not supported.

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
    required String bleDeviceId,
    required int bleRssi,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.attendanceEndpoint,
        data: {
          'user_id': userId,
          'session_id': sessionId,
          'face_verified': faceVerified,
          'ble_device_id': bleDeviceId,
          'ble_rssi': bleRssi,
        },
      );

      return response.statusCode == 200;
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
      final response = await _dio.put(
        '${AppConstants.sessionEndpoint}/$sessionId/end',
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleApiError(e, 'Session ending');
      return false;
    }
  }

  Future<List<Session>> getSessions(String userId) async {
    try {
      final response = await _dio.get(
        AppConstants.sessionEndpoint,
        queryParameters: {'lecturer_id': userId},
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
        AppConstants.exitEndpoint,
        data: {'user_id': userId, 'face_id': faceId, 'qr_data': qrData},
      );

      return ExitResult.fromJson(response.data);
    } on DioException catch (e) {
      return ExitResult(
        allowed: false,
        message: _getErrorMessage(e, 'Exit processing'),
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
        '${AppConstants.attendanceEndpoint}/manual',
        data: {
          'student_ids': studentIds,
          'session_id': sessionId,
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
      final token = prefs.getString('auth_token');
      
      // Check if token exists and is not expired
      if (token != null) {
        // Check if token is expired
        final tokenData = parseJwt(token);
        final expiryTimestamp = tokenData['exp'] as int?;
        
        if (expiryTimestamp != null) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
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
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        return null;
      }
      
      final response = await _dio.post(
        '${AppConstants.baseUrl}/token/refresh/',
        data: {
          'refresh': refreshToken,
        },
      );
      
      if (response.statusCode == 200 && response.data['access'] != null) {
        final newToken = response.data['access'] as String;
        await prefs.setString('auth_token', newToken);
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
    _bleScanController.close();
    _qrController.dispose();
  }

  Future<List<User>> getAllStudents() async {
    try {
      final response = await _dio.get(AppConstants.adminUsersEndpoint);
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

  Future<bool> updateCampusTag(String userId, String tag) async {
    try {
      final response = await _dio.put(
        '${AppConstants.adminUsersEndpoint}/$userId/tag',
        data: {'campus_tag': tag},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleApiError(e, 'Update campus tag');
      return false;
    }
  }

  Future<bool> updateLeaveStatus(
    String leaveId,
    String status,
    String? comments,
  ) async {
    try {
      final response = await _dio.put(
        '${AppConstants.adminLeaveEndpoint}/$leaveId/status',
        data: {'status': status, 'comments': comments},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
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
          'user_id': userId,
          'session_id': sessionId,
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
      final response = await _dio.post(
        '${AppConstants.exitEndpoint}/emergency',
        data: {
          'user_id': userId,
          'reason': reason,
          'emergency': true,
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
      return ExitResult(
        allowed: false,
        message: errorMsg,
      );
    }
  }
}
