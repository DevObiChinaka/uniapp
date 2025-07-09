import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../utils/utils.dart';

@immutable
class User {
  final String id;
  final String name;
  final String role;
  final String? faceId;
  final String? program;
  final String? campusTag;

  const User({
    required this.id,
    required this.name,
    required this.role,
    this.faceId,
    this.program,
    this.campusTag,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      faceId: json['face_id'] as String?,
      program: json['program'] as String?,
      campusTag: json['campus_tag'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'face_id': faceId,
      'program': program,
      'campus_tag': campusTag,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? role,
    String? faceId,
    String? program,
    String? campusTag,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      faceId: faceId ?? this.faceId,
      program: program ?? this.program,
      campusTag: campusTag ?? this.campusTag,
    );
  }
}

@immutable
class AttendanceRecord {
  final String id;
  final String userId;
  final String sessionId;
  final DateTime timestamp;
  final String method;
  final String? program;

  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.timestamp,
    required this.method,
    this.program,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      method: json['method'] as String,
      program: json['program'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'program': program,
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? userId,
    String? sessionId,
    DateTime? timestamp,
    String? method,
    String? program,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      program: program ?? this.program,
    );
  }
}

@immutable
class Session {
  final String id;
  final String lecturerId;
  final String program;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSessions;
  final double passThreshold;

  const Session({
    required this.id,
    required this.lecturerId,
    required this.program,
    required this.startTime,
    this.endTime,
    this.totalSessions = 10,
    this.passThreshold = 0.7,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      lecturerId: json['lecturer_id'] as String,
      program: json['program'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime:
          json['end_time'] != null
              ? DateTime.parse(json['end_time'] as String)
              : null,
      totalSessions: json['total_sessions'] as int? ?? 10,
      passThreshold: (json['pass_threshold'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lecturer_id': lecturerId,
      'program': program,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_sessions': totalSessions,
      'pass_threshold': passThreshold,
    };
  }

  String toBlePayload() {
    return jsonEncode({
      'session_id': id,
      'lecturer_id': lecturerId,
      'program': program,
      'start_time': startTime.millisecondsSinceEpoch,
    });
  }

  bool get isActive => endTime == null;

  factory Session.empty() =>
      Session(id: '', lecturerId: '', program: '', startTime: DateTime(0));
}

@immutable
class LeaveRequest {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // pending, approved, denied
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? reviewComments;

  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerId,
    this.reviewComments,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      reason: json['reason'] as String,
      status: json['status'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      reviewedAt:
          json['reviewed_at'] != null
              ? DateTime.parse(json['reviewed_at'] as String)
              : null,
      reviewerId: json['reviewer_id'] as String?,
      reviewComments: json['review_comments'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewer_id': reviewerId,
      'review_comments': reviewComments,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  LeaveRequest copyWith({
    String? id,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewerId,
    String? reviewComments,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewComments: reviewComments ?? this.reviewComments,
    );
  }
}

@immutable
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM d, y').format(timestamp);
  }
}

@immutable
class ExitResult {
  final bool allowed;
  final String message;
  final String? studentName;
  final String? studentPhotoUrl;

  const ExitResult({
    required this.allowed,
    required this.message,
    this.studentName,
    this.studentPhotoUrl,
  });

  factory ExitResult.fromJson(Map<String, dynamic> json) {
    return ExitResult(
      allowed: json['allowed'] as bool,
      message: json['message'] as String,
      studentName: json['student_name'] as String?,
      studentPhotoUrl: json['student_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowed': allowed,
      'message': message,
      'student_name': studentName,
      'student_photo_url': studentPhotoUrl,
    };
  }

  ExitResult copyWith({
    bool? allowed,
    String? message,
    String? studentName,
    String? studentPhotoUrl,
  }) {
    return ExitResult(
      allowed: allowed ?? this.allowed,
      message: message ?? this.message,
      studentName: studentName ?? this.studentName,
      studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
    );
  }
}

@immutable
class SystemLog {
  final String id;
  final String type; // attendance, exit, security, system
  final String event;
  final DateTime timestamp;
  final String? userId;
  final String? details;

  const SystemLog({
    required this.id,
    required this.type,
    required this.event,
    required this.timestamp,
    this.userId,
    this.details,
  });

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'] as String,
      type: json['type'] as String,
      event: json['event'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['user_id'] as String?,
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'event': event,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'details': details,
    };
  }

  String get timeAgo => Utils.timeAgo(timestamp);
}
