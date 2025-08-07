import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_constants.dart';
import '../services/core_services.dart';
import '../services/face_service.dart' hide FaceException;
import '../models/models.dart' hide SyncStatus;
import '../models/program.dart' as prog;
import '../services/session_service.dart';
import '../main.dart';
import '../utils/offline_utils.dart';
import '../models/sync_status.dart';
import '../models/face_exception.dart';
import '../utils/location_utils.dart';

class AppProvider with ChangeNotifier {
  /// Fetch attendance records for a session (lecturer workflow)
  Future<void> fetchLecturerSessionAttendance(String sessionId) async {
    try {
      _setLoading(true, 'Loading attendance records...');
      final records = await coreServices.getLecturerSessionAttendance(
        sessionId,
      );
      _attendanceRecords = records;
      debugPrint(
        '[AppProvider] Loaded ${records.length} attendance records for session $sessionId',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Error loading attendance records: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch and update the current user profile (ensures PK is used for id)
  Future<void> fetchProfile() async {
    debugPrint('[AppProvider] Fetching latest user profile...');
    final latestUser = await coreServices.fetchProfile();
    if (latestUser != null) {
      // Update _userId and _allStudents with correct PK
      _userId = latestUser.id;
      // Ensure program is a Program object
      var userObj = latestUser;
      if (userObj.program is Map<String, dynamic>) {
        final progObj = prog.Program.fromJson(
          userObj.program as Map<String, dynamic>,
        );
        userObj = userObj.copyWith(program: progObj as prog.Program?);
      } else if (userObj.program is! prog.Program && userObj.program != null) {
        userObj = userObj.copyWith(program: null);
      }
      // Do NOT overwrite id with universityId
      final index = _allStudents.indexWhere((s) => s.id == userObj.id);
      if (index != -1) {
        _allStudents[index] = userObj;
        debugPrint(
          '[AppProvider] Updated _allStudents with PK: id=${userObj.id}, universityId=${userObj.universityId}',
        );
      } else {
        _allStudents.add(userObj);
        debugPrint(
          '[AppProvider] Added latestUser to _allStudents: id=${userObj.id}, universityId=${userObj.universityId}',
        );
      }
      notifyListeners();
    }
  }

  /// Fetch the active session for the current student (program/level)
  Future<void> fetchActiveSession() async {
    debugPrint('[AppProvider] _allStudents before getCurrentUser:');
    for (var s in _allStudents) {
      debugPrint(
        '  id: ${s.id}, program: ${s.program}, type: ${s.program.runtimeType}',
      );
    }
    try {
      // Always fetch the latest profile before fetching sessions
      final latestUser = await coreServices.fetchProfile();
      if (latestUser != null && _role == AppConstants.studentRole) {
        // Always set _userId to latestUser.universityId for students
        _userId = latestUser.universityId;
        // Ensure program is a Program object
        var userObj = latestUser;
        if (userObj.program is Map<String, dynamic>) {
          final progObj = prog.Program.fromJson(
            userObj.program as Map<String, dynamic>,
          );
          userObj = userObj.copyWith(program: progObj as prog.Program?);
        } else if (userObj.program is! prog.Program &&
            userObj.program != null) {
          userObj = userObj.copyWith(program: null);
        }
        // Ensure id is universityId for students
        userObj = userObj.copyWith(id: latestUser.universityId);
        // Update or add user in _allStudents using universityId
        final index = _allStudents.indexWhere((s) => s.id == _userId);
        if (index != -1) {
          _allStudents[index] = userObj;
          debugPrint(
            '[AppProvider] After profile update: program=${_allStudents[index].program}, type=${_allStudents[index].program.runtimeType}',
          );
        } else {
          _allStudents.add(userObj);
          debugPrint(
            '[AppProvider] Added latestUser to _allStudents: id=${userObj.id}, universityId=${userObj.universityId}, program=${userObj.program}, type=${userObj.program.runtimeType}',
          );
        }
        // Immediately check getCurrentUser
        final currentUser = getCurrentUser();
        debugPrint(
          '[AppProvider] getCurrentUser after update: program=${currentUser?.program}, type=${currentUser?.program.runtimeType}',
        );
      }
      final user = getCurrentUser();
      debugPrint(
        '[AppProvider] getCurrentUser: user=$user, program=${user?.program}, type=${user?.program.runtimeType}',
      );
      final userId = user?.universityId ?? _userId;
      var program = user?.program;
      // Defensive: ensure program is a Program object
      if (program != null && program is Map<String, dynamic>) {
        program = prog.Program.fromJson(program as Map<String, dynamic>);
      }
      final level =
          user?.level ??
          (user != null && user.toJson().containsKey('level')
              ? user.toJson()['level']
              : null);
      debugPrint('[AppProvider] Student program from profile: ${program}');
      if (userId == null || program == null)
        throw Exception('User, program, or level missing');
      final sessions = await coreServices.getSessions(userId, isStudent: true);
      debugPrint('[AppProvider] Backend returned sessions:');
      for (var s in sessions) {
        debugPrint(
          '  id: ${s.id}, program: ${s.program}, level: ${s.level}, isActive: ${s.isActive}, '
          'lecturer: ${s.lecturerUsername}, courseId: ${s.courseId}',
        );
      }
      debugPrint(
        '[AppProvider] Filtering for program: ${program}, level: ${level}',
      );
      // Refactored: filter sessions using course's programs and level
      List<Session> filtered = [];
      for (var s in sessions) {
        if (s.courseId == null) {
          debugPrint('  Skipping session id=${s.id}: no courseId');
          continue;
        }
        final course = await coreServices.getCourse(s.courseId!);
        if (course == null) {
          debugPrint('  Skipping session id=${s.id}: course not found');
          continue;
        }
        final courseProgramNames = course.programs.map((p) => p.name).toList();
        final studentProgramName = program.name;
        final programMatch = courseProgramNames.contains(studentProgramName);
        // If student level is null, match all courses; otherwise match exact level
        final levelMatch = (level == null || course.level == level);

        debugPrint(
          '  Session id=${s.id}: course=${course.code}, coursePrograms=${courseProgramNames}, '
          'courseLevel=${course.level}, programMatch=${programMatch}, levelMatch=${levelMatch}',
        );

        if (!programMatch || !levelMatch) {
          debugPrint(
            '  Skipping session id=${s.id}: programMatch=${programMatch}, levelMatch=${levelMatch}',
          );
          continue;
        }
        debugPrint('  ✓ Including session id=${s.id} in filtered results');
        filtered.add(s);
      }
      debugPrint('[AppProvider] Filtered sessions count: ${filtered.length}');
      _sessions = filtered;

      // For active session, find the first session that is actually active
      final activeSessions = filtered.where((s) => s.isActive).toList();
      _activeSession = activeSessions.isNotEmpty ? activeSessions.first : null;

      if (_activeSession != null) {
        debugPrint(
          '[AppProvider] Active session selected: id=${_activeSession!.id}',
        );
      } else {
        debugPrint('[AppProvider] No active session found after filtering.');
        if (filtered.isNotEmpty) {
          debugPrint(
            '[AppProvider] Available sessions (but none active): ${filtered.length}',
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching active session: $e');
    }
  }

  /// Fetch current session attendance records for real-time tracking
  Future<void> fetchCurrentAttendanceRecords() async {
    try {
      final userId = getCurrentUser()?.universityId ?? _userId;
      if (userId == null) throw Exception('User ID missing');
      final records = await coreServices.getAttendanceRecords(userId);
      _attendanceRecords = records;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching current attendance records: $e');
    }
  }

  /// Request an emergency exit (for use by emergency_exit_screen)
  Future<bool> requestEmergencyExit({
    required String userId,
    required String reason,
  }) async {
    _isExitProcessing = true;
    _lastExitResult = null;
    notifyListeners();

    try {
      final result = await coreServices.requestEmergencyExit(
        userId: userId,
        reason: reason,
      );
      _lastExitResult = result;
      return result.allowed;
    } catch (e) {
      debugPrint('Emergency exit error: $e');
      _lastExitResult = ExitResult(
        allowed: false,
        message: 'Error processing emergency exit: ${e.toString()}',
      );
      return false;
    } finally {
      _isExitProcessing = false;
      notifyListeners();
    }
  }

  /// Update the status of a leave request (approve/deny) - positional args for admin_dashboard compatibility
  Future<bool> updateLeaveStatus(
    String leaveRequestId,
    LeaveRequestStatus status, [
    String? comments,
  ]) async {
    _setLoading(true, 'Updating leave status...');
    try {
      final success = await coreServices.updateLeaveStatus(
        leaveRequestId,
        status.value, // Pass string value as required by core_services
        comments ?? '',
      );
      if (success) {
        final index = _allLeaveRequests.indexWhere(
          (r) => r.id == leaveRequestId,
        );
        if (index != -1) {
          _allLeaveRequests[index] = _allLeaveRequests[index].copyWith(
            status: status,
          );
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating leave status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Alias for updateLeaveStatusWithComments for backward compatibility
  Future<bool> updateLeaveStatusWithComments(
    String leaveRequestId,
    LeaveRequestStatus status, [
    String? comments,
  ]) async {
    return updateLeaveStatus(leaveRequestId, status, comments);
  }

  // Program state
  List<prog.Program> _programs = [];
  List<prog.Program> get programs => _programs;

  Future<void> fetchPrograms() async {
    try {
      final response = await coreServices.dio.get('/programs/');
      final data = response.data as List;
      _programs =
          data.map((e) {
            if (e is Map<String, dynamic>) {
              return prog.Program.fromJson(e);
            } else if (e is Map) {
              return prog.Program.fromJson(Map<String, dynamic>.from(e));
            } else {
              throw Exception('Invalid program data format');
            }
          }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch programs: $e');
    }
  }

  /// Activate a session (start/mark as active)
  Future<bool> activateSession(String sessionId) async {
    _setLoading(true, 'Activating session...');
    bool result = false;
    try {
      // Fetch device location before starting session
      final position = await LocationUtils.getCurrentLocation();
      if (position == null) {
        debugPrint(
          'ACTIVATE SESSION: Location unavailable. Cannot start session.',
        );
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Location is required to start a session.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
      debugPrint(
        'ACTIVATE SESSION: Device location: '
        'Lat: ${position.latitude}, Lng: ${position.longitude}',
      );

      // Pass location to backend if supported (add to API call if needed)
      debugPrint(
        'ACTIVATE SESSION: Calling coreServices.activateSession with sessionId: ' +
            sessionId,
      );
      final success = await coreServices.activateSession(
        sessionId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      debugPrint(
        'ACTIVATE SESSION: coreServices.activateSession returned: ' +
            success.toString(),
      );
      if (!success) return false;

      // Fetch lecturer username
      String lecturerUsername = '';
      try {
        final response = await coreServices.dio.get(
          '${AppConstants.baseUrl}/my-profile/',
        );
        if (response.statusCode == 200 && response.data != null) {
          final userJson = response.data['data'] ?? response.data;
          lecturerUsername = userJson['username'] ?? '';
          debugPrint(
            'ACTIVATE SESSION: Lecturer username fetched from backend: ' +
                lecturerUsername,
          );
        } else {
          debugPrint(
            'ACTIVATE SESSION: Failed to fetch lecturer profile, using cached username',
          );
          lecturerUsername =
              _lecturerUsername ?? getCurrentUser()?.username ?? '';
        }
      } catch (e) {
        debugPrint(
          'ACTIVATE SESSION: Error fetching lecturer profile: ' + e.toString(),
        );
        lecturerUsername =
            _lecturerUsername ?? getCurrentUser()?.username ?? '';
      }
      if (lecturerUsername.isEmpty) {
        debugPrint('ACTIVATE SESSION: ERROR - Lecturer username is missing.');
        return false;
      }

      debugPrint(
        'ACTIVATE SESSION: Fetching updated sessions for lecturer: ' +
            lecturerUsername,
      );
      final updatedSessions = await fetchLecturerSessions(lecturerUsername);
      _sessions = updatedSessions;
      // Update active session reference
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      debugPrint(
        'ACTIVATE SESSION: Session index in _sessions: ' + index.toString(),
      );
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(isActive: true);
        _activeSession = _sessions[index];
        debugPrint(
          'ACTIVATE SESSION: Set _activeSession to session: ' +
              _activeSession.toString(),
        );
      }

      // BLE broadcast and backend BLE status update removed
      notifyListeners();
      result = true;
    } catch (e) {
      debugPrint('ACTIVATE SESSION: Exception: ' + e.toString());
      result = false;
    } finally {
      _setLoading(false);
    }
    return result;
  }

  /// Update a session's configuration and notify listeners
  Future<void> updateSession(Session updatedSession) async {
    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _sessions[index] = updatedSession;
      if (_activeSession != null && _activeSession!.id == updatedSession.id) {
        _activeSession = updatedSession;
      }
      notifyListeners();
      // TODO: Persist to backend if needed
    }
  }

  /// Returns a list of students whose attendance for the given session is below 70% (flagged)
  List<User> getFlaggedStudentsForSession(String sessionId) {
    // Count attendance per student for this session
    final Map<String, int> attendanceCount = {};
    final sessionRecords = _attendanceRecords.where(
      (r) => r.sessionId == sessionId,
    );
    for (var record in sessionRecords) {
      attendanceCount[record.userId] =
          (attendanceCount[record.userId] ?? 0) + 1;
    }
    // Find total number of sessions for this sessionId (should be 1, but keep for extensibility)
    final int totalMarks = sessionRecords.length;
    if (totalMarks == 0) return _allStudents;
    // Flag students below 70%
    final List<User> flagged = [];
    for (var student in _allStudents) {
      final count = attendanceCount[student.id] ?? 0;
      final percent = count / totalMarks;
      if (percent < 0.7) {
        flagged.add(student);
      }
    }
    return flagged;
  }

  /// Remove an attendance record by its id and notify listeners
  void removeAttendanceRecord(String recordId) {
    _attendanceRecords.removeWhere((record) => record.id == recordId);
    _calculateAttendanceStats();
    notifyListeners();
  }

  final CoreServices coreServices;
  final FaceService faceService;
  late SessionService sessionService;

  // User state
  String? _role;
  String? _faceId;
  String? _userId;
  String? _currentProgram;

  // BLE state removed

  // Session state
  Session? _activeSession;
  final bool _inSession = false;
  List<Session> _sessions = [];
  double _attendanceThreshold = AppConstants.defaultPassThreshold;
  int _totalSessions = AppConstants.defaultTotalSessions;

  // Attendance state
  List<AttendanceRecord> _attendanceRecords = [];
  Map<String, int> _attendanceStats = {};

  // Leave state
  List<LeaveRequest> _leaveRequests = [];
  bool _isSubmittingLeave = false;

  // Notification state
  List<AppNotification> _notifications = [];

  // Returns the current user object

  // Gate exit state
  bool _isExitProcessing = false;
  ExitResult? _lastExitResult;

  // Admin state
  List<User> _allStudents = [];
  List<LeaveRequest> _allLeaveRequests = [];
  List<SystemLog> _systemLogs = [];
  List<ExitLog> _exitHistory = [];
  List<AttendanceRecord> _attendanceHistory = [];

  // Loading states
  bool _isLoading = false;
  String? _loadingMessage;

  // Offline support
  List<OfflineAttendanceRecord> _offlineAttendanceRecords = [];
  SyncStatus _syncStatus = SyncStatus.initial();
  bool _isNetworkAvailable = true;
  Timer? _syncTimer;

  // Sync state
  bool _isSyncingOfflineAttendance = false;
  List<OfflineAttendanceRecord> get _pendingOfflineAttendance =>
      _offlineAttendanceRecords.where((record) => !record.isSynced).toList();

  AppProvider({required this.coreServices, required this.faceService});

  /// Call this after successful login to preload all required data for all screens
  Future<void> preloadAllData() async {
    try {
      debugPrint('[AppProvider] Preloading all data after login...');
      await fetchProfile();
      await fetchActiveSession();
      await fetchAttendanceHistory(); // This will fetch attendance history for the history screen
      await fetchPrograms();
      await fetchLeaveRequests();

      // Add other fetches as needed (leave requests, logs, etc.)
      debugPrint('[AppProvider] Data preload complete.');
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Error during data preload: $e');
    }
  }

  // Getters
  String? get role => _role;
  String? get faceId => _faceId;
  String? get userId => _userId;
  // BLE scanning getter removed
  bool get inSession => _inSession;
  Session? get activeSession => _activeSession;
  List<Session> get sessions => _sessions;
  double get attendanceThreshold => _attendanceThreshold;
  int get totalSessions => _totalSessions;
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;
  Map<String, int> get attendanceStats => _attendanceStats;
  List<LeaveRequest> get leaveRequests => _leaveRequests;

  Future<void> fetchLeaveRequests() async {
    try {
      final userId = getCurrentUser()?.universityId ?? _userId;
      if (userId == null) throw Exception('User ID missing');
      final requests = await coreServices.getLeaveRequests(userId);
      _leaveRequests = requests;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
    }
  }

  bool get isSubmittingLeave => _isSubmittingLeave;
  List<AppNotification> get notifications => _notifications;
  bool get isExitProcessing => _isExitProcessing;
  ExitResult? get lastExitResult => _lastExitResult;
  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;
  List<User> get allStudents => _allStudents;
  List<LeaveRequest> get allLeaveRequests => _allLeaveRequests;
  List<SystemLog> get systemLogs => _systemLogs;
  List<ExitLog> get exitHistory => _exitHistory;
  List<AttendanceRecord> get attendanceHistory => _attendanceHistory;
  // BLE device getter removed

  // Offline attendance getters
  List<OfflineAttendanceRecord> get pendingOfflineAttendance =>
      _pendingOfflineAttendance;
  bool get isSyncingOfflineAttendance => _isSyncingOfflineAttendance;
  bool get isNetworkAvailable => _isNetworkAvailable;
  List<OfflineAttendanceRecord> get offlineAttendanceRecords =>
      _offlineAttendanceRecords;
  SyncStatus get syncStatus => _syncStatus;
  bool get hasPendingRecords =>
      _offlineAttendanceRecords.any((record) => !record.isSynced);

  // Setters
  set attendanceThreshold(double value) {
    _attendanceThreshold = value;
    notifyListeners();
  }

  set totalSessions(int value) {
    _totalSessions = value;
    notifyListeners();
  }

  // Create a new session with specified parameters
  Future<String> createSession({
    required String lecturerUsername,
    required String program,
    required int totalSessions,
    required double passThreshold,
    required String level,
    required String courseId,
  }) async {
    _setLoading(true, 'Creating session...');
    try {
      final session = Session(
        id: '', // Backend will assign
        lecturerUsername: lecturerUsername,
        program: program,
        startTime: DateTime.now(),
        totalSessions: totalSessions,
        passThreshold: passThreshold,
        level: level,
        courseId: courseId,
      );
      final success = await coreServices.createSession(session);
      return success ? 'success' : '';
    } catch (e) {
      debugPrint('Create session error: $e');
      return '';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch all sessions for a lecturer
  Future<List<Session>> fetchLecturerSessions(String lecturerUsername) async {
    _setLoading(true, 'Fetching sessions...');
    try {
      // Use username for session fetch
      final username = getCurrentUser()?.username ?? lecturerUsername;
      return await coreServices.getSessions(username, isStudent: false);
    } catch (e) {
      debugPrint('Error fetching lecturer sessions: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // End an active session
  Future<bool> endSession(String sessionId) async {
    _setLoading(true, 'Ending session...');
    try {
      final success = await coreServices.endSession(sessionId);
      if (success) {
        // Optionally refresh sessions or update local state
        String lecturerUsername =
            _lecturerUsername ?? getCurrentUser()?.username ?? '';
        final updatedSessions = await fetchLecturerSessions(lecturerUsername);
        _sessions = updatedSessions;
        // Update active session reference
        _activeSession = null;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error ending session: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get attendance statistics for a specific session
  Future<Map<String, dynamic>> getSessionAttendanceStats(
    String sessionId,
  ) async {
    _setLoading(true, 'Fetching attendance statistics...');

    try {
      // In a real app, this would fetch data from the server
      // Return mock statistics based on the session ID
      final mockStats = {
        'present_count': 10,
        'absent_count': 5,
        'total_students': 15,
        'attendance_percentage': 66.7,
        'session_id': sessionId,
        'students': [
          {
            'id': '1',
            'name': 'John Doe',
            'status': 'present',
            'time': '10:15 AM',
          },
          {
            'id': '2',
            'name': 'Jane Smith',
            'status': 'present',
            'time': '10:05 AM',
          },
          {'id': '3', 'name': 'Bob Johnson', 'status': 'absent', 'time': null},
        ],
      };

      return mockStats;
    } catch (e) {
      debugPrint('Error getting session attendance stats: $e');
      return {
        'error': 'Failed to load attendance statistics',
        'present_count': 0,
        'absent_count': 0,
        'total_students': 0,
        'attendance_percentage': 0,
      };
    } finally {
      _setLoading(false);
    }
  }

  // Mark attendance using QR code
  Future<void> markQRAttendance(
    String sessionId,
    String lecturerUsername,
  ) async {
    if (_faceId == null) return;

    _setLoading(true, 'Verifying QR attendance...');
    try {
      // Verify face
      final verification = await faceService.verifyFace(_faceId!);
      if (!verification.isIdentical ||
          verification.confidence < AppConstants.faceConfidenceThreshold) {
        throw FaceException('Face verification failed');
      }

      if (_isNetworkAvailable) {
        try {
          // Try to mark attendance with QR method online
          final success = await coreServices.markQRAttendance(
            userId: _userId!,
            sessionId: sessionId,
            faceVerified: true,
          );

          if (success) {
            // Find session to get currentPeriod
            final session = _sessions.firstWhere(
              (s) => s.id == sessionId,
              orElse:
                  () => Session(
                    id: sessionId,
                    lecturerUsername: '',
                    program: _currentProgram ?? '',
                    startTime: DateTime.now(),
                    totalSessions: 1,
                    passThreshold: 0.7,
                    isActive: false,
                    currentPeriod: 1,
                  ),
            );
            _attendanceRecords.add(
              AttendanceRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                userId: _userId!,
                sessionId: sessionId,
                timestamp: DateTime.now(),
                method: 'QR+Face',
                program: _currentProgram,
                period: session.currentPeriod,
              ),
            );
            _calculateAttendanceStats();
            notifyListeners();
            return;
          }
        } catch (networkError) {
          debugPrint(
            'Network error, saving QR attendance offline: $networkError',
          );
        }
      }

      // If we got here, either there's no network or the online request failed
      // Save the attendance record offline
      final recordId = DateTime.now().millisecondsSinceEpoch.toString();

      final offlineRecord = OfflineAttendanceRecord(
        id: recordId,
        userId: _userId!,
        sessionId: sessionId,
        timestamp: DateTime.now(),
        method: 'QR+Face',
        program: _currentProgram,
        createdAt: DateTime.now(),
        extraData: {
          'face_verified': true,
          'verification_confidence': verification.confidence,
          'lecturer_username': lecturerUsername,
        },
      );

      await _addOfflineAttendanceRecord(offlineRecord);

      // Also add to local records for immediate UI update
      // Find session to get currentPeriod
      final session = _sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse:
            () => Session(
              id: sessionId,
              lecturerUsername: '',
              program: _currentProgram ?? '',
              startTime: DateTime.now(),
              totalSessions: 1,
              passThreshold: 0.7,
              isActive: false,
              currentPeriod: 1,
            ),
      );
      _attendanceRecords.add(
        offlineRecord.toAttendanceRecord().copyWith(
          period: session.currentPeriod,
        ),
      );
      _calculateAttendanceStats();
      notifyListeners();

      // Show offline indicator
      _showOfflineAttendanceMessage();
    } catch (e) {
      debugPrint('QR Attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Process gate exit request
  Future<void> processGateExit(String qrData) async {
    _isExitProcessing = true;
    _lastExitResult = null;
    notifyListeners();

    try {
      // Simulate processing time
      await Future.delayed(const Duration(seconds: 1));

      // Parse QR data (in a real app this would be verified with backend)
      bool isValid = qrData.startsWith('EXIT:');

      // Set the exit result
      _lastExitResult = ExitResult(
        allowed: isValid,
        message:
            isValid
                ? 'Exit approved. You may leave the campus.'
                : 'Invalid exit code. Please try again or contact security.',
      );
    } catch (e) {
      debugPrint('Exit error: $e');
      _lastExitResult = ExitResult(
        allowed: false,
        message: 'Error processing exit: ${e.toString()}',
      );
    } finally {
      _isExitProcessing = false;
      notifyListeners();
    }
  }

  // Clear the last exit result
  void clearExitResult() {
    _lastExitResult = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }

  void _calculateAttendanceStats() {
    final stats = <String, int>{};
    for (var record in _attendanceRecords) {
      final program = record.program ?? _currentProgram ?? 'default';
      stats.update(program, (count) => count + 1, ifAbsent: () => 1);
    }
    _attendanceStats = stats;
    notifyListeners();
  }

  // Add offline attendance record to local storage
  Future<bool> _addOfflineAttendanceRecord(
    OfflineAttendanceRecord record,
  ) async {
    try {
      // Add to in-memory list
      _offlineAttendanceRecords.add(record);

      // Update sync status
      _updateSyncStatus();

      // Save to persistent storage
      final success = await OfflineDataManager.saveOfflineAttendance(record);
      return success;
    } catch (e) {
      debugPrint('Error saving offline attendance: $e');
      return false;
    }
  }

  // Update the sync status with latest counts
  void _updateSyncStatus() {
    final totalRecords = _offlineAttendanceRecords.length;
    final syncedRecords =
        _offlineAttendanceRecords.where((r) => r.isSynced).length;

    _syncStatus = SyncStatus(
      totalRecords: totalRecords,
      syncedRecords: syncedRecords,
      lastSyncAttempt: DateTime.now(),
      isCurrentlySyncing: _isSyncingOfflineAttendance,
    );
    notifyListeners();
  }

  void _showOfflineAttendanceMessage() {
    // This would be implemented with a global key-based SnackBar in a real app
    debugPrint(
      'Attendance saved offline. Will sync when connection is available.',
    );

    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved offline. Will sync when online.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // Initialization methods
  Future<void> initialize() async {
    // Initialize services
    // Initialize sessionService with a reference to this AppProvider
    sessionService = SessionService(this);

    // Initialize offline data
    await _initializeOfflineSupport();

    // Start sync timer if auto-sync is enabled
    if (AppConstants.enableAutoSync) {
      _startSyncTimer();
    }

    notifyListeners();
  }

  Future<void> _initializeOfflineSupport() async {
    // Load any offline attendance records
    await _loadOfflineAttendance();

    // Check network connectivity
    _isNetworkAvailable = await _checkNetworkConnectivity();

    // Setup periodic connectivity checks
    Timer.periodic(const Duration(minutes: 5), (_) async {
      _isNetworkAvailable = await _checkNetworkConnectivity();

      if (_isNetworkAvailable && hasPendingRecords) {
        // Auto-sync when connection is available
        await syncOfflineAttendance();
      }

      notifyListeners();
    });
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Simple connectivity check
      final result = await http.get(Uri.parse(AppConstants.baseUrl));
      return result.statusCode >= 200 && result.statusCode < 300;
    } catch (e) {
      debugPrint('Network check error: $e');
      return false;
    }
  }

  void _startSyncTimer() {
    // Set up periodic sync attempts (every 5 minutes)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_isNetworkAvailable &&
          hasPendingRecords &&
          !_isSyncingOfflineAttendance) {
        await syncOfflineAttendance();
      }
    });
  }

  // Get current user details - change to public method
  User? getCurrentUser() {
    debugPrint('getCurrentUser called: _role=$_role, _userId=$_userId');
    if (_role == AppConstants.studentRole) {
      return _allStudents.firstWhere(
        (s) => s.id == _userId,
        orElse:
            () => User(
              id: _userId!,
              name: 'Student $_userId',
              role: AppConstants.studentRole,
            ),
      );
    } else if (_role == AppConstants.adminRole) {
      if (_adminUser != null) return _adminUser;
      return User(
        id: _userId ?? '',
        name: _adminName ?? 'Admin',
        role: AppConstants.adminRole,
        username: _adminUsername,
        firstName: _adminFirstName,
        lastName: _adminLastName,
        email: _adminEmail,
        profilePictureUrl: _adminProfilePictureUrl,
      );
    } else if (_role == AppConstants.lecturerRole) {
      if (_lecturerUser != null) return _lecturerUser;
      return User(
        id: _userId ?? '',
        name: _lecturerName ?? 'Lecturer',
        role: AppConstants.lecturerRole,
        username: _lecturerUsername,
        firstName: _lecturerFirstName,
        lastName: _lecturerLastName,
        email: _lecturerEmail,
        profilePictureUrl: _lecturerProfilePictureUrl,
      );
    } else if (_role == AppConstants.securityRole) {
      // Handle security users - use admin fields that are populated during login
      debugPrint(
        'Creating security user: name=$_adminName, username=$_adminUsername, id=$_userId',
      );
      return User(
        id: _userId ?? 'security_user',
        name: _adminName ?? 'Security Officer',
        role: AppConstants.securityRole,
        username: _adminUsername,
        firstName: _adminFirstName,
        lastName: _adminLastName,
        email: _adminEmail,
        profilePictureUrl: _adminProfilePictureUrl,
      );
    }
    return null;
  }

  // BLE scan methods removed

  // BLE attendance marking method removed

  // Manual attendance marking (always uses current active session from backend)
  Future<void> markManualAttendance({
    required List<String> studentIds,
    String? program,
  }) async {
    _setLoading(true, 'Marking attendance...');
    try {
      // Always fetch latest sessions and use the active one
      if (_role == AppConstants.lecturerRole) {
        final username = _lecturerUsername ?? getCurrentUser()?.username;
        final sessions = await fetchLecturerSessions(username ?? '');
        final activeSession = sessions.firstWhere(
          (s) => s.isActive,
          orElse: () {
            debugPrint('No active session found for manual attendance');
            throw Exception('No active session found');
          },
        );
        final sessionId = activeSession.id;
        final sessionProgram = program ?? activeSession.program;
        for (String studentId in studentIds) {
          // Find session to get currentPeriod
          final session = _sessions.firstWhere(
            (s) => s.id == sessionId,
            orElse:
                () => Session(
                  id: sessionId,
                  lecturerUsername: '',
                  program: sessionProgram,
                  startTime: DateTime.now(),
                  totalSessions: 1,
                  passThreshold: 0.7,
                  isActive: false,
                  currentPeriod: 1,
                ),
          );
          final attendanceRecord = AttendanceRecord(
            id: '${DateTime.now().millisecondsSinceEpoch}_$studentId',
            userId: studentId,
            sessionId: sessionId,
            timestamp: DateTime.now(),
            method: 'manual',
            program: sessionProgram,
            period: session.currentPeriod,
          );
          final success = await coreServices.markAttendance(
            userId: studentId,
            sessionId: sessionId,
            faceVerified:
                false, // Manual attendance doesn't require face verification
          );
          if (success) {
            _attendanceRecords.add(attendanceRecord);
          }
        }
        notifyListeners();
      } else {
        debugPrint('Manual attendance only allowed for lecturers');
        throw Exception('Manual attendance only allowed for lecturers');
      }
    } catch (e) {
      debugPrint('Error marking manual attendance: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Submit a new leave request
  Future<bool> submitLeaveRequest(
    DateTime start,
    DateTime end,
    String reason,
  ) async {
    if (_isSubmittingLeave) return false;

    _isSubmittingLeave = true;
    notifyListeners();

    try {
      final leaveRequest = LeaveRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _userId!,
        startDate: start,
        endDate: end,
        reason: reason,
        status: LeaveRequestStatus.pending,
        submittedAt: DateTime.now(),
      );

      if (!_isNetworkAvailable) {
        // Store locally for later sync
        _leaveRequests.add(leaveRequest);
        notifyListeners();
        return true;
      }

      final success = await coreServices.submitLeaveRequest(leaveRequest);
      if (success) {
        _leaveRequests.add(leaveRequest);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Leave request error: $e');
      return false;
    } finally {
      _isSubmittingLeave = false;
      notifyListeners();
    }
  }

  // Face registration
  Future<bool> registerFace() async {
    if (_role != AppConstants.studentRole) return false;

    _setLoading(true, 'Registering face...');
    try {
      final faceId = await faceService.registerFace();
      if (faceId != null) {
        _faceId = faceId;
        // Store face ID securely
        const storage = FlutterSecureStorage();
        await storage.write(key: 'face_id_$_userId', value: faceId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Face registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Offline support
  Future<void> _loadOfflineAttendance() async {
    try {
      // Load offline attendance from shared preferences
      // Initialize with empty list (in a real app, load from SharedPreferences)
      _offlineAttendanceRecords = [];
      _updateSyncStatus();
    } catch (e) {
      debugPrint('Error loading offline attendance: $e');
    }
  }

  Future<void> syncOfflineAttendance() async {
    if (_isSyncingOfflineAttendance || _pendingOfflineAttendance.isEmpty) {
      return;
    }

    _isSyncingOfflineAttendance = true;
    _syncStatus = _syncStatus.copyWith(isCurrentlySyncing: true);
    notifyListeners();

    try {
      int syncedCount = 0;
      final recordsToSync = List<OfflineAttendanceRecord>.from(
        _pendingOfflineAttendance,
      );

      for (final record in recordsToSync) {
        try {
          // In a real app, we would send the record to the server
          // For now, we'll simulate success
          final success = true;

          if (success) {
            // Update the record status
            final index = _offlineAttendanceRecords.indexWhere(
              (r) => r.id == record.id,
            );
            if (index >= 0) {
              _offlineAttendanceRecords[index] = record.copyWith(
                isSynced: true,
              );
              syncedCount++;
            }
          }
        } catch (e) {
          debugPrint('Error syncing record ${record.id}: $e');
        }
      }

      // Update storage with synced records
      // In a real app, save to SharedPreferences
      // For now, we just update the state in memory

      // Update status
      _syncStatus = _syncStatus.copyWith(
        syncedRecords: _syncStatus.syncedRecords + syncedCount,
        lastSyncAttempt: DateTime.now(),
        isCurrentlySyncing: false,
        lastError:
            syncedCount < recordsToSync.length
                ? 'Some records failed to sync'
                : null,
      );

      if (syncedCount > 0) {
        _showSyncSuccessMessage(syncedCount);
      }
    } catch (e) {
      _syncStatus = _syncStatus.copyWith(
        isCurrentlySyncing: false,
        lastError: e.toString(),
      );
      debugPrint('Sync error: $e');
    } finally {
      _isSyncingOfflineAttendance = false;
      notifyListeners();
    }
  }

  void _showSyncSuccessMessage(int count) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('Synced $count attendance records'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Additional methods
  Future<List<AttendanceRecord>> fetchAttendanceRecords(
    String sessionId,
  ) async {
    _setLoading(true, 'Loading attendance records...');

    try {
      // In a real app, this would fetch from the server
      // For now, return mock data
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay

      return [
        AttendanceRecord(
          id: '1',
          userId: _userId ?? 'unknown',
          sessionId: sessionId,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          method: 'QR',
          program: _currentProgram,
          period: 1,
        ),
        AttendanceRecord(
          id: '2',
          userId: _userId ?? 'unknown',
          sessionId: sessionId,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          method: 'QR',
          program: _currentProgram,
          period: 1,
        ),
      ];
    } catch (e) {
      debugPrint('Error fetching attendance records: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Map<String, int> getUserAttendanceStats() {
    return _attendanceStats;
  }

  // Admin user cache
  User? _adminUser;
  String? _adminName;
  String? _adminUsername;
  String? _adminFirstName;
  String? _adminLastName;
  String? _adminEmail;
  String? _adminProfilePictureUrl;

  User? _lecturerUser;
  String? _lecturerName;
  String? _lecturerUsername;
  String? _lecturerFirstName;
  String? _lecturerLastName;
  String? _lecturerEmail;
  String? _lecturerProfilePictureUrl;

  Future<void> loadUserData() async {
    debugPrint('[loadUserData] Starting to load user data...');
    _setLoading(true, 'Loading user data...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      debugPrint('[loadUserData] Found role in SharedPreferences: $role');
      final userId =
          prefs.getString('university_id') ?? prefs.getString('user_id');
      final username = prefs.getString('username');
      final firstName = prefs.getString('first_name');
      final lastName = prefs.getString('last_name');
      final email = prefs.getString('email');
      final profilePictureUrl = prefs.getString('profile_picture');

      debugPrint('[loadUserData] SharedPreferences values:');
      debugPrint('  role: $role');
      debugPrint('  userId: $userId');
      debugPrint('  username: $username');
      debugPrint('  firstName: $firstName');
      debugPrint('  lastName: $lastName');

      if (role == AppConstants.adminRole) {
        debugPrint('[loadUserData] Loading admin user data');
        _role = AppConstants.adminRole;
        _userId = userId;
        _adminUsername = username;
        _adminFirstName = firstName;
        _adminLastName = lastName;
        _adminEmail = email;
        _adminProfilePictureUrl = profilePictureUrl;
        _adminName =
            (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true)
                ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
                : (username ?? 'Admin');
        try {
          final response = await coreServices.dio.get(
            '${AppConstants.baseUrl}/my-profile/',
          );
          if (response.statusCode == 200 && response.data != null) {
            final userJson = response.data['data'] ?? response.data;
            _adminUser = User.fromJson(userJson);
            _adminName = _adminUser?.name;
            _adminUsername = _adminUser?.username;
            _adminFirstName = _adminUser?.firstName;
            _adminLastName = _adminUser?.lastName;
            _adminEmail = _adminUser?.email;
            _adminProfilePictureUrl = _adminUser?.profilePictureUrl;
          }
        } catch (e) {
          debugPrint('Failed to fetch admin profile from backend: $e');
        }
      } else if (role == AppConstants.lecturerRole) {
        debugPrint('[loadUserData] Loading lecturer user data');
        _role = AppConstants.lecturerRole;
        _userId = userId;
        _lecturerUsername = username;
        _lecturerFirstName = firstName;
        _lecturerLastName = lastName;
        _lecturerEmail = email;
        _lecturerProfilePictureUrl = profilePictureUrl;
        _lecturerName =
            (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true)
                ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
                : (username ?? 'Lecturer');
        try {
          final response = await coreServices.dio.get(
            '${AppConstants.baseUrl}/my-profile/',
          );
          if (response.statusCode == 200 && response.data != null) {
            final userJson = response.data['data'] ?? response.data;
            _lecturerUser = User.fromJson(userJson);
            _lecturerName = _lecturerUser?.name;
            _lecturerUsername = _lecturerUser?.username;
            _lecturerFirstName = _lecturerUser?.firstName;
            _lecturerLastName = _lecturerUser?.lastName;
            _lecturerEmail = _lecturerUser?.email;
            _lecturerProfilePictureUrl = _lecturerUser?.profilePictureUrl;
          }
        } catch (e) {
          debugPrint('Failed to fetch lecturer profile from backend: $e');
        }
      } else if (role == AppConstants.securityRole) {
        debugPrint(
          '[loadUserData] Loading security user data from SharedPreferences',
        );
        debugPrint(
          '[loadUserData] Security user data: role=$role, userId=$userId, username=$username',
        );
        _role = AppConstants.securityRole;
        _userId = userId; // Set user ID from SharedPreferences
        _adminUsername = username; // Reuse admin fields for security
        _adminFirstName = firstName;
        _adminLastName = lastName;
        _adminEmail = email;
        _adminProfilePictureUrl = profilePictureUrl;
        _adminName =
            (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true)
                ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
                : (username ?? 'Security Officer');
        debugPrint(
          '[loadUserData] Security user loaded: name=$_adminName, username=$_adminUsername, id=$_userId',
        );
        try {
          final response = await coreServices.dio.get(
            '${AppConstants.baseUrl}/my-profile/',
          );
          if (response.statusCode == 200 && response.data != null) {
            final userJson = response.data['data'] ?? response.data;
            final securityUser = User.fromJson(userJson);
            // Use the actual user data from backend as source of truth
            _userId = securityUser.id; // Use actual user ID
            _adminName = securityUser.name;
            _adminUsername = securityUser.username;
            _adminFirstName = securityUser.firstName;
            _adminLastName = securityUser.lastName;
            _adminEmail = securityUser.email;
            _adminProfilePictureUrl = securityUser.profilePictureUrl;
            debugPrint(
              '[loadUserData] Updated security user from backend: name=$_adminName, username=$_adminUsername, id=$_userId',
            );
          }
        } catch (e) {
          // Fallback to username from SharedPreferences if backend call fails
          _userId = username ?? 'security_user';
          debugPrint('Failed to fetch security profile from backend: $e');
          debugPrint('[loadUserData] Using fallback security ID: $_userId');
        }
      } else if (role == AppConstants.securityRole) {
        debugPrint('Setting up security user with role: $role');
        debugPrint('Security setup data: userId=$userId, username=$username');
        _role = AppConstants.securityRole;
        _userId = username; // Security users use username as their ID
        _adminUsername = username; // Reuse admin fields for security
        _adminFirstName = firstName;
        _adminLastName = lastName;
        _adminEmail = email;
        _adminProfilePictureUrl = profilePictureUrl;
        _adminName =
            (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true)
                ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
                : (username ?? 'Security Officer');
        debugPrint(
          'Security user set up: name=$_adminName, username=$_adminUsername, role=$_role',
        );
        try {
          final response = await coreServices.dio.get(
            '${AppConstants.baseUrl}/my-profile/',
          );
          if (response.statusCode == 200 && response.data != null) {
            final userJson = response.data['data'] ?? response.data;
            final securityUser = User.fromJson(userJson);
            _adminName = securityUser.name;
            _adminUsername = securityUser.username;
            _adminFirstName = securityUser.firstName;
            _adminLastName = securityUser.lastName;
            _adminEmail = securityUser.email;
            _adminProfilePictureUrl = securityUser.profilePictureUrl;
          }
        } catch (e) {
          debugPrint('Failed to fetch security profile from backend: $e');
        }
      } else {
        debugPrint(
          '[loadUserData] Defaulting to student role. Role from SharedPreferences: $role',
        );
        _role = AppConstants.studentRole;
        _userId = userId ?? '12345';
        _currentProgram = 'Computer Science';
        _favorites = ['CS101', 'MATH202', 'PHYS101'];
        _calculateAttendanceStats();
      }
      // After loading user data, preload all data for student
      if (_role == AppConstants.studentRole) {
        await preloadAllData();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // User favorites
  List<String> _favorites = [];

  // Favorites
  List<String> get favorites => _favorites;

  void toggleFavorite(String itemId) {
    if (_favorites.contains(itemId)) {
      _favorites.remove(itemId);
    } else {
      _favorites.add(itemId);
    }
    notifyListeners();

    // In a real app, save to SharedPreferences
    // For demo purposes, we just update the in-memory list
  }

  Future<List<LeaveRequest>> getLeaveRequests() async {
    _setLoading(true, 'Loading leave requests...');

    try {
      // In a real app, this would fetch from the server
      // For now, return mock data or previously submitted requests
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay
      return _leaveRequests;
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Change password method
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      debugPrint('Changing password...');

      final response = await coreServices.dio.post(
        '/api/users/change-password/',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      debugPrint('Change password response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Password changed successfully');
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      throw Exception('Failed to change password');
    }
  }

  // Logout method to clear user data and redirect
  Future<bool> logout() async {
    _setLoading(true, 'Logging out...');

    try {
      // Clear all user data
      _role = null;
      _faceId = null;
      _userId = null;
      _currentProgram = null;
      _attendanceRecords = [];
      _attendanceStats = {};
      _leaveRequests = [];
      _notifications = [];

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('refresh');
      await prefs.remove('role');
      await prefs.remove('university_id');
      await prefs.remove('first_name');
      await prefs.remove('last_name');
      await prefs.remove('username');
      await prefs.setBool('is_logged_in', false);

      // In a real app, notify the server about logout
      try {
        await coreServices.logout();
      } catch (e) {
        // Even if server logout fails, continue with local logout
        debugPrint('Server logout failed: $e');
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Logout error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Admin methods
  Future<List<User>> fetchAllStudents() async {
    _setLoading(true, 'Fetching students...');
    try {
      final students = await coreServices.fetchAllStudents();
      _allStudents = students;
      notifyListeners();
      return students;
    } catch (e) {
      debugPrint('Error fetching all students: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllLeaveRequests() async {
    _setLoading(true, 'Fetching leave requests...');
    try {
      final requests = await coreServices.fetchAllLeaveRequests();
      _allLeaveRequests = requests;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching all leave requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchSystemLogs() async {
    _setLoading(true, 'Fetching system logs...');
    try {
      final logs = await coreServices.fetchSystemLogs();
      _systemLogs = logs;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching system logs: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchExitHistory([String? userId]) async {
    _setLoading(true, 'Fetching exit history...');
    try {
      final history = await coreServices.getExitHistory(userId);
      _exitHistory = history;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching exit history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAttendanceHistory([String? userId]) async {
    _setLoading(true, 'Fetching attendance history...');
    try {
      debugPrint(
        '[AppProvider] Fetching attendance history for userId: $userId',
      );
      final history = await coreServices.getAttendanceHistory(userId);
      debugPrint('[AppProvider] Received ${history.length} attendance records');
      for (var record in history) {
        debugPrint(
          '[AppProvider] Attendance: id=${record.id}, sessionId=${record.sessionId}, method=${record.method}',
        );
      }
      _attendanceHistory = history;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching attendance history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    _setLoading(true, 'Updating profile...');
    try {
      await coreServices.updateProfile(profileData);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCampusTag(String studentId, bool isOnCampus) async {
    _setLoading(true, 'Updating campus tag...');
    try {
      await coreServices.updateCampusTag(studentId, isOnCampus);
      // Update local list
      final index = _allStudents.indexWhere(
        (student) => student.id == studentId,
      );
      if (index >= 0) {
        _allStudents[index] = _allStudents[index].copyWith(
          isOnCampus: isOnCampus,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating campus tag: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<LeaveRequest>> fetchApprovedLeaves() async {
    _setLoading(true, 'Fetching approved leave requests...');
    try {
      final allRequests = await coreServices.fetchAllLeaveRequests();
      final approvedRequests =
          allRequests
              .where((request) => request.status == LeaveRequestStatus.approved)
              .toList();
      return approvedRequests;
    } catch (e) {
      debugPrint('Error fetching approved leaves: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> verifyExitRequest({
    required String universityId,
    required String gateId,
  }) async {
    _setLoading(true, 'Verifying exit request...');
    try {
      // Check if student has approved leave
      final approvedLeaves = await fetchApprovedLeaves();
      final hasApprovedLeave = approvedLeaves.any(
        (leave) =>
            leave.userId == universityId &&
            leave.startDate.isBefore(DateTime.now()) &&
            leave.endDate.isAfter(DateTime.now()),
      );

      // Create QR data for exit
      final qrData =
          'EXIT:$universityId:$gateId:${DateTime.now().millisecondsSinceEpoch}:${hasApprovedLeave ? 'APPROVED' : 'STANDARD'}';
      final faceId = 'face_$universityId'; // Mock face ID

      // Use core services to process exit request
      final exitResult = await coreServices.processExit(
        userId: universityId,
        faceId: faceId,
        qrData: qrData,
      );

      return {
        'success': exitResult.allowed,
        'message': exitResult.message,
        'studentName': exitResult.studentName,
      };
    } catch (e) {
      debugPrint('Error verifying exit request: $e');
      return {'success': false, 'message': 'Error verifying exit request: $e'};
    } finally {
      _setLoading(false);
    }
  }
}
