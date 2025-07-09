import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'app_constants.dart';
import '../services/core_services.dart';
import '../services/face_service.dart';
import '../models/models.dart';
import '../services/session_service.dart';

class AppProvider with ChangeNotifier {
  final CoreServices coreServices;
  final FaceService faceService;
  late SessionService sessionService;

  // User state
  String? _role;
  String? _faceId;
  String? _userId;
  String? _currentProgram;

  // BLE state
  bool _isScanning = false;
  List<DiscoveredDevice> _bleDevices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  // Session state
  Session? _activeSession;
  bool _inSession = false;
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

  // Gate exit state
  bool _isExitProcessing = false;
  ExitResult? _lastExitResult;

  // Admin state
  List<User> _allStudents = [];
  List<LeaveRequest> _allLeaveRequests = [];
  List<SystemLog> _systemLogs = [];

  // Loading states
  bool _isLoading = false;
  String? _loadingMessage;

  AppProvider({required this.coreServices, required this.faceService});

  // Getters
  String? get role => _role;
  String? get faceId => _faceId;
  String? get userId => _userId;
  bool get isScanning => _isScanning;
  bool get inSession => _inSession;
  Session? get activeSession => _activeSession;
  List<Session> get sessions => _sessions;
  double get attendanceThreshold => _attendanceThreshold;
  int get totalSessions => _totalSessions;
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;
  Map<String, int> get attendanceStats => _attendanceStats;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  bool get isSubmittingLeave => _isSubmittingLeave;
  List<AppNotification> get notifications => _notifications;
  bool get isExitProcessing => _isExitProcessing;
  ExitResult? get lastExitResult => _lastExitResult;
  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;
  List<User> get allStudents => _allStudents;
  List<LeaveRequest> get allLeaveRequests => _allLeaveRequests;
  List<SystemLog> get systemLogs => _systemLogs;
  List<DiscoveredDevice> get bleDevices => _bleDevices;

  // Setters
  set attendanceThreshold(double value) {
    _attendanceThreshold = value;
    notifyListeners();
  }

  set totalSessions(int value) {
    _totalSessions = value;
    notifyListeners();
  }

  // Initialization methods
  Future<void> initialize() async {
    sessionService = SessionService(this);
    await _loadPersistentData();
    await _fetchInitialData();

    // Auto-refresh data periodically
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_role == AppConstants.studentRole) {
        _fetchStudentData();
      } else if (_role == AppConstants.lecturerRole) {
        _fetchLecturerData();
      } else if (_role == AppConstants.adminRole) {
        _fetchAdminData();
      }
    });
  }

  // Get current user details
  User? _getCurrentUser() {
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
    }
    return null;
  }

  Future<void> _loadPersistentData() async {
    // Removed secure data loading as per the change request
  }

  Future<void> _fetchInitialData() async {
    if (_role == null) return;

    _setLoading(true, 'Loading data...');
    try {
      if (_role == AppConstants.studentRole) {
        await _fetchStudentData();
      } else if (_role == AppConstants.lecturerRole) {
        await _fetchLecturerData();
      } else if (_role == AppConstants.adminRole) {
        await _fetchAdminData();
      }
    } catch (e) {
      debugPrint('Initial data fetch error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _fetchStudentData() async {
    final records = await coreServices.getAttendanceRecords(_userId!);
    _attendanceRecords = records;
    _calculateAttendanceStats();

    final leaves = await coreServices.getLeaveRequests(_userId!);
    _leaveRequests = leaves;

    final notifs = await coreServices.getNotifications(_userId!);
    _notifications = notifs;
    notifyListeners();
  }

  Future<void> _fetchLecturerData() async {
    final sessions = await coreServices.getSessions(_userId!);
    _sessions = sessions;

    final active = sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session.empty(),
    );
    if (active.id.isNotEmpty) {
      _activeSession = active;
      _inSession = true;
    }
    notifyListeners();
  }

  Future<void> _fetchAdminData() async {
    await fetchAllStudents();
    await fetchAllLeaveRequests();
    await fetchSystemLogs();
  }

  // Role management
  Future<void> setRole(String role) async {
    _role = role;
    // Removed secure data setting as per the change request
    notifyListeners();
  }

  // Face registration
  Future<bool> registerFace() async {
    if (_role != AppConstants.studentRole) return false;

    _setLoading(true, 'Registering face...');
    try {
      final faceId = await faceService.registerFace();
      if (faceId != null) {
        _faceId = faceId;
        // Removed secure data setting as per the change request
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

  // BLE Methods
  Future<void> startBleScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _bleDevices = [];
    notifyListeners();

    final flutterReactiveBle = FlutterReactiveBle();
    _scanSubscription = flutterReactiveBle
        .scanForDevices(withServices: [])
        .listen(
          (DiscoveredDevice device) {
            if (!_bleDevices.any((d) => d.id == device.id)) {
              _bleDevices.add(device);
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint('BLE Scan error: $e');
            _isScanning = false;
            notifyListeners();
          },
        );
  }

  Future<void> stopBleScan() async {
    await _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  // Attendance Methods
  Future<void> markAttendance(
    DiscoveredDevice device,
    String sessionId,
    int bleRssi,
  ) async {
    if (_faceId == null) return;

    _setLoading(true, 'Verifying attendance...');
    try {
      // Verify face
      final verification = await faceService.verifyFace(_faceId!);
      if (!verification.isIdentical ||
          verification.confidence < AppConstants.faceConfidenceThreshold) {
        throw FaceException('Face verification failed');
      }

      // Mark attendance
      final success = await coreServices.markAttendance(
        userId: _userId!,
        sessionId: sessionId,
        faceVerified: true,
        bleDeviceId: device.id,
        bleRssi: bleRssi,
      );

      if (success) {
        _attendanceRecords.add(
          AttendanceRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(), // Added id
            userId: _userId!,
            sessionId: sessionId,
            timestamp: DateTime.now(),
            method: 'BLE+Face',
            program: _currentProgram,
          ),
        );
        _calculateAttendanceStats();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
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

  // Leave Methods
  Future<void> submitLeaveRequest(
    DateTime start,
    DateTime end,
    String reason,
  ) async {
    if (_isSubmittingLeave) return;

    _isSubmittingLeave = true;
    notifyListeners();

    try {
      final leave = LeaveRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Added id
        userId: _userId!,
        startDate: start,
        endDate: end,
        reason: reason,
        status: 'pending',
        submittedAt: DateTime.now(),
      );

      final success = await coreServices.submitLeaveRequest(leave);
      if (success) {
        _leaveRequests.add(leave);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Leave error: $e');
      rethrow;
    } finally {
      _isSubmittingLeave = false;
      notifyListeners();
    }
  }

  // Gate Exit Methods
  Future<void> processGateExit(String qrData) async {
    if (_isExitProcessing || _faceId == null) return;

    _isExitProcessing = true;
    _lastExitResult = null;
    notifyListeners();

    try {
      // Verify face
      final verification = await faceService.verifyFace(_faceId!);
      if (!verification.isIdentical ||
          verification.confidence < AppConstants.faceConfidenceThreshold) {
        throw FaceException('Face verification failed');
      }

      // Process exit
      final result = await coreServices.processExit(
        userId: _userId!,
        faceId: _faceId!,
        qrData: qrData,
      );

      // Add student info to result
      _lastExitResult = result.copyWith(studentName: _getCurrentUser()?.name);

      // Add notification
      _notifications.insert(
        0,
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type:
              result.allowed
                  ? AppConstants.notifExitAllowed
                  : AppConstants.notifExitDenied,
          title: result.allowed ? 'Exit Approved' : 'Exit Denied',
          body: result.message,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Exit error: $e');
      _lastExitResult = ExitResult(
        allowed: false,
        message: 'Error: ${e.toString()}',
      );
      notifyListeners();
    } finally {
      _isExitProcessing = false;
      notifyListeners();
    }
  }

  void clearExitResult() {
    _lastExitResult = null;
    notifyListeners();
  }

  // Notification Methods
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  // Utility Methods
  void _setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    coreServices.stopBleScan();
    super.dispose();
  }

  // Admin methods
  Future<void> fetchAllStudents() async {
    _setLoading(true, 'Loading students...');
    try {
      _allStudents = await coreServices.getAllStudents();
      notifyListeners();
    } catch (e) {
      debugPrint('Students error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllLeaveRequests() async {
    _setLoading(true, 'Loading leave requests...');
    try {
      _allLeaveRequests = await coreServices.getAllLeaveRequests();
      notifyListeners();
    } catch (e) {
      debugPrint('Leave requests error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchSystemLogs() async {
    _setLoading(true, 'Loading logs...');
    try {
      _systemLogs = await coreServices.getSystemLogs();
      notifyListeners();
    } catch (e) {
      debugPrint('Logs error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateCampusTag(String userId, String tag) async {
    _setLoading(true, 'Updating tag...');
    try {
      final success = await coreServices.updateCampusTag(userId, tag);
      if (success) {
        final index = _allStudents.indexWhere((s) => s.id == userId);
        if (index != -1) {
          _allStudents[index] = _allStudents[index].copyWith(campusTag: tag);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Tag error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateLeaveStatus(
    String leaveId,
    String status,
    String? comments,
  ) async {
    _setLoading(true, 'Updating leave...');
    try {
      final success = await coreServices.updateLeaveStatus(
        leaveId,
        status,
        comments,
      );
      if (success) {
        final index = _allLeaveRequests.indexWhere((l) => l.id == leaveId);
        if (index != -1) {
          _allLeaveRequests[index] = _allLeaveRequests[index].copyWith(
            status: status,
            reviewComments: comments,
            reviewedAt: DateTime.now(),
          );
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Leave error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> endActiveSession() async {
    if (_activeSession != null) {
      await coreServices.endSession(_activeSession!.id);
      _inSession = false;
      _activeSession = null;
      notifyListeners();
    }
  }

  Future<bool> createSession(Session session) async {
    _setLoading(true, 'Creating session...');
    try {
      final success = await coreServices.createSession(session);
      if (success) {
        _activeSession = session;
        _inSession = true;
        _sessions.insert(0, session);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Create session error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
