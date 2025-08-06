import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../utils/utils.dart';
import 'dart:convert';
import 'program.dart' as prog;

// Program model now imported from program.dart

@immutable
class Geofence {
  final double latitude;
  final double longitude;
  final double radius;
  final String? id;

  const Geofence({
    required this.latitude,
    required this.longitude,
    this.radius = 50.0,
    this.id,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 50.0,
      id: json['id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      if (id != null) 'id': id,
    };
  }

  Geofence copyWith({
    double? latitude,
    double? longitude,
    double? radius,
    String? id,
  }) {
    return Geofence(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      id: id ?? this.id,
    );
  }
}

@immutable
class User {
  final String id;
  final String name;
  final String role;
  final String? faceId;
  final prog.Program? program;
  final String? campusTag;
  final bool isOnCampus;
  final String? universityId;
  final String? profilePictureUrl;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? email;

  const User({
    required this.id,
    required this.name,
    required this.role,
    this.faceId,
    this.program,
    this.campusTag,
    this.isOnCampus = false,
    this.universityId,
    this.profilePictureUrl,
    this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.level,
  });
  final String? level;

  factory User.fromJson(Map<String, dynamic> json) {
    prog.Program? mappedProgram;
    final rawProgram = json['program'];
    if (rawProgram != null) {
      if (rawProgram is Map<String, dynamic>) {
        mappedProgram = prog.Program.fromJson(rawProgram);
      } else if (rawProgram is String) {
        // If backend ever sends a string, try to parse as JSON
        try {
          mappedProgram = prog.Program.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawProgram)),
          );
        } catch (e) {
          debugPrint(
            '[User.fromJson] Failed to parse program string: $rawProgram',
          );
        }
      } else if (rawProgram is int) {
        // Backend is sending program ID as integer, create a minimal Program object
        mappedProgram = prog.Program(
          id: rawProgram,
          name: 'Program $rawProgram', // Fallback name
        );
        debugPrint(
          '[User.fromJson] Converted program ID $rawProgram to Program object',
        );
      } else {
        debugPrint(
          '[User.fromJson] Unknown program type: ${rawProgram.runtimeType}',
        );
      }
    }
    debugPrint('[User.fromJson] Mapped program: ${mappedProgram?.toJson()}');
    // Always use backend PK (integer) for id, and university_id for universityId
    return User(
      id: (json['id'] ?? '').toString(), // PK (integer as string)
      universityId: json['university_id']?.toString(), // university ID string
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      faceId: json['face_id'] as String?,
      program: mappedProgram,
      campusTag: json['campus_tag'] as String?,
      isOnCampus: json['is_on_campus'] as bool? ?? false,
      profilePictureUrl:
          json['profile_picture_url'] as String? ??
          json['profile_picture'] as String?,
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'face_id': faceId,
      'program': program?.toJson(),
      'campus_tag': campusTag,
      'is_on_campus': isOnCampus,
      'university_id': universityId,
      'profile_picture': profilePictureUrl,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'level': level,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? role,
    String? faceId,
    prog.Program? program,
    String? campusTag,
    bool? isOnCampus,
    String? universityId,
    String? profilePictureUrl,
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? level,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      faceId: faceId ?? this.faceId,
      program: program ?? this.program,
      campusTag: campusTag ?? this.campusTag,
      isOnCampus: isOnCampus ?? this.isOnCampus,
      universityId: universityId ?? this.universityId,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      level: level ?? this.level,
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
  final int period;

  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.timestamp,
    required this.method,
    this.program,
    required this.period,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    String parseString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    int parseInt(dynamic value) {
      if (value == null) return 1;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 1;
      return 1;
    }

    // Accept both 'session_id' and 'session' from backend
    String sessionIdValue = '';
    if (json.containsKey('session_id')) {
      sessionIdValue = parseString(json['session_id']);
    } else if (json.containsKey('session')) {
      sessionIdValue = parseString(json['session']);
    }
    return AttendanceRecord(
      id: parseString(json['id']),
      userId: parseString(json['user_id']),
      sessionId: sessionIdValue,
      timestamp: DateTime.parse(json['timestamp'] as String),
      method: parseString(json['method']),
      program: json['program'] as String?,
      period: parseInt(json['period']),
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
      'period': period,
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? userId,
    String? sessionId,
    DateTime? timestamp,
    String? method,
    String? program,
    int? period,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      program: program ?? this.program,
      period: period ?? this.period,
    );
  }
}

@immutable
class Session {
  Session copyWith({
    String? id,
    String? lecturerUsername,
    String? program,
    DateTime? startTime,
    DateTime? endTime,
    int? totalSessions,
    double? passThreshold,
    bool? isActive,
    String? level,
    String? courseId,
    Geofence? geofence,
  }) {
    return Session(
      id: id ?? this.id,
      lecturerUsername: lecturerUsername ?? this.lecturerUsername,
      program: program ?? this.program,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalSessions: totalSessions ?? this.totalSessions,
      passThreshold: passThreshold ?? this.passThreshold,
      isActive: isActive ?? this.isActive,
      level: level ?? this.level,
      courseId: courseId ?? this.courseId,
      currentPeriod: currentPeriod,
      geofence: geofence ?? this.geofence,
    );
  }

  final String id;
  final String lecturerUsername;
  final String program;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSessions;
  final double passThreshold;
  final bool isActive;
  final int currentPeriod;
  final String? level;
  final String? courseId;
  final Geofence? geofence;

  const Session({
    required this.id,
    required this.lecturerUsername,
    required this.program,
    required this.startTime,
    this.endTime,
    this.totalSessions = 10,
    this.passThreshold = 0.7,
    this.isActive = false,
    this.currentPeriod = 0,
    this.level,
    this.courseId,
    this.geofence,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final lecturerUsername = (json['lecturer_username'] ?? '').toString();
    debugPrint('Session.fromJson: lecturer_username = $lecturerUsername');

    // Debug the course data structure
    debugPrint('Session.fromJson: Raw course data = ${json['course']}');
    debugPrint('Session.fromJson: Raw course_id data = ${json['course_id']}');

    return Session(
      id: (json['id'] ?? '').toString(),
      lecturerUsername: lecturerUsername,
      program: (json['program'] ?? '').toString(),
      startTime:
          DateTime.tryParse(json['start_time']?.toString() ?? '') ??
          DateTime.now(),
      endTime:
          json['end_time'] != null
              ? DateTime.tryParse(json['end_time']?.toString() ?? '')
              : null,
      totalSessions: json['total_sessions'] as int? ?? 10,
      passThreshold: (json['pass_threshold'] as num?)?.toDouble() ?? 0.7,
      isActive: json['is_active'] as bool? ?? (json['end_time'] == null),
      currentPeriod: json['current_period'] as int? ?? 0,
      level: json['level']?.toString(),
      courseId:
          (() {
            final raw = json['course_id'] ?? json['course'];
            if (raw == null) return null;
            if (raw is Map<String, dynamic> && raw.containsKey('id')) {
              return raw['id'].toString();
            }
            // If it's a stringified object, try to parse and extract id
            if (raw is String && raw.startsWith('{') && raw.contains('id')) {
              try {
                final parsed = jsonDecode(raw);
                if (parsed is Map && parsed.containsKey('id')) {
                  return parsed['id'].toString();
                }
              } catch (_) {}
            }
            // Otherwise, just return as string
            return raw.toString();
          })(),
      geofence:
          json['geofence'] != null
              ? Geofence.fromJson(json['geofence'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lecturer_username': lecturerUsername,
      'program': program,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_sessions': totalSessions,
      'pass_threshold': passThreshold,
      'is_active': isActive,
      'current_period': currentPeriod,
      if (level != null) 'level': level,
      if (courseId != null) 'course_id': courseId,
      if (geofence != null) 'geofence': geofence!.toJson(),
    };
  }

  // ...existing code...

  factory Session.empty() => Session(
    id: '',
    lecturerUsername: '',
    program: '',
    startTime: DateTime(0),
    geofence: null,
  );
}

@immutable
class LeaveRequest {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveRequestStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? reviewComments;
  final String? studentName;
  final String? studentUniversityId;

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
    this.studentName,
    this.studentUniversityId,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      reason: json['reason'] as String,
      status: LeaveRequestStatus.fromString(json['status'] as String),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      reviewedAt:
          json['reviewed_at'] != null
              ? DateTime.parse(json['reviewed_at'] as String)
              : null,
      reviewerId: json['reviewer_id'] as String?,
      reviewComments: json['review_comments'] as String?,
      studentName: json['student_name'] as String?,
      studentUniversityId: json['student_university_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'reason': reason,
      'status': status.value,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewer_id': reviewerId,
      'review_comments': reviewComments,
      'student_name': studentName,
      'student_university_id': studentUniversityId,
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
    LeaveRequestStatus? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewerId,
    String? reviewComments,
    String? studentName,
    String? studentUniversityId,
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
      studentName: studentName ?? this.studentName,
      studentUniversityId: studentUniversityId ?? this.studentUniversityId,
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

@immutable
class OfflineAttendanceRecord {
  final String id;
  final String userId;
  final String sessionId;
  final DateTime timestamp;
  final String method;
  final String? program;
  final bool isSynced;
  final DateTime createdAt;
  final Map<String, dynamic> extraData;

  const OfflineAttendanceRecord({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.timestamp,
    required this.method,
    this.program,
    this.isSynced = false,
    required this.createdAt,
    this.extraData = const {},
  });

  factory OfflineAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      method: json['method'] as String,
      program: json['program'] as String?,
      isSynced: json['is_synced'] as bool? ?? false,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      extraData:
          json['extra_data'] != null
              ? Map<String, dynamic>.from(json['extra_data'] as Map)
              : const {},
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
      'is_synced': isSynced,
      'created_at': createdAt.toIso8601String(),
      'extra_data': extraData,
    };
  }

  OfflineAttendanceRecord copyWith({
    String? id,
    String? userId,
    String? sessionId,
    DateTime? timestamp,
    String? method,
    String? program,
    bool? isSynced,
    DateTime? createdAt,
    Map<String, dynamic>? extraData,
  }) {
    return OfflineAttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      program: program ?? this.program,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      extraData: extraData ?? this.extraData,
    );
  }

  // Convert to regular AttendanceRecord
  AttendanceRecord toAttendanceRecord() {
    return AttendanceRecord(
      id: id,
      userId: userId,
      sessionId: sessionId,
      timestamp: timestamp,
      method: method,
      program: program,
      period: extraData['period'] is int ? extraData['period'] as int : 1,
    );
  }
}

@immutable
class SyncStatus {
  final DateTime lastSyncAttempt;
  final bool isCurrentlySyncing;
  final int pendingRecords;
  final String? lastError;

  const SyncStatus({
    required this.lastSyncAttempt,
    this.isCurrentlySyncing = false,
    this.pendingRecords = 0,
    this.lastError,
  });

  factory SyncStatus.initial() {
    return SyncStatus(
      lastSyncAttempt: DateTime.now().subtract(Duration(days: 1)),
      isCurrentlySyncing: false,
      pendingRecords: 0,
    );
  }

  SyncStatus copyWith({
    DateTime? lastSyncAttempt,
    bool? isCurrentlySyncing,
    int? pendingRecords,
    String? lastError,
  }) {
    return SyncStatus(
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      isCurrentlySyncing: isCurrentlySyncing ?? this.isCurrentlySyncing,
      pendingRecords: pendingRecords ?? this.pendingRecords,
      lastError: lastError ?? this.lastError,
    );
  }
}

enum LeaveRequestStatus {
  pending('pending'),
  approved('approved'),
  denied('denied');

  final String value;
  const LeaveRequestStatus(this.value);

  factory LeaveRequestStatus.fromString(String status) {
    return LeaveRequestStatus.values.firstWhere(
      (e) => e.value == status.toLowerCase(),
      orElse: () => LeaveRequestStatus.pending,
    );
  }

  @override
  String toString() => value;
}
