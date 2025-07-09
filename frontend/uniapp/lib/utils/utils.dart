import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../screens/app_constants.dart';

class Utils {
  // HMAC Generation
  static String generateHmac(String data) {
    final key = utf8.encode(AppConstants.hmacSecretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  // QR Validation
  static bool validateQrPayload(String qrData) {
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
      final expectedSignature = generateHmac(timestamp.toString());
      return expectedSignature == receivedSignature;
    } catch (e) {
      debugPrint('QR validation error: $e');
      return false;
    }
  }

  // Distance estimation using RSSI
  static double estimateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0; // Invalid value

    const n = 2.0; // Path loss exponent (2 in free space)
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  // Date Formatting
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  // Form Validators
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Both dates are required';
    if (end.isBefore(start)) return 'End date cannot be before start date';
    if (start.isBefore(DateTime.now()))
      return 'Start date cannot be in the past';
    return null;
  }

  // Notification Formatting
  static IconData notificationIcon(String type) {
    switch (type) {
      case AppConstants.notifLeaveApproved:
        return Icons.check_circle;
      case AppConstants.notifLeaveDenied:
        return Icons.cancel;
      case AppConstants.notifSessionStart:
        return Icons.notifications_active;
      case AppConstants.notifSessionEnd:
        return Icons.notifications_off;
      case AppConstants.notifLowAttendance:
        return Icons.warning;
      case AppConstants.notifExitAllowed:
        return Icons.exit_to_app;
      case AppConstants.notifExitDenied:
        return Icons.block;
      case AppConstants.notifSecurityAlert:
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  static Color notificationColor(String type) {
    switch (type) {
      case AppConstants.notifLeaveApproved:
      case AppConstants.notifExitAllowed:
        return Colors.green;
      case AppConstants.notifLeaveDenied:
      case AppConstants.notifExitDenied:
      case AppConstants.notifSecurityAlert:
        return Colors.red;
      case AppConstants.notifLowAttendance:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // Attendance Percentage Calculation
  static double calculateAttendancePercentage(int attended, int totalSessions) {
    if (totalSessions == 0) return 0.0;
    return (attended / totalSessions) * 100;
  }

  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  // Time Ago Formatting
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM d, y').format(date);
  }

  // Error Message Handling
  static String getErrorMessage(dynamic error) {
    if (error is DioError) {
      return error.response?.data['error'] ?? error.message ?? 'Request failed';
    }
    return error.toString();
  }

  // Secure Data Key Generation
  static String generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}

// Custom exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (${statusCode ?? 0})';
}

// Dio error extension
extension DioErrorExtension on DioError {
  String get errorMessage {
    return response?.data?['error'] ?? message ?? 'Network request failed';
  }
}
