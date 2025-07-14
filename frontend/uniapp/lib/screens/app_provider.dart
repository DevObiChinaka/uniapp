import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'app_constants.dart';
import '../services/core_services.dart';
import '../services/face_service.dart';
import '../models/models.dart';
import '../services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart'; // For navigatorKey
import '../utils/offline_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

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
  bool _isBroadcasting = false;
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

  // Offline support
  List<OfflineAttendanceRecord> _offlineAttendanceRecords = [];
  SyncStatus _syncStatus = SyncStatus.initial();
  bool _isNetworkAvailable = true;
  Timer? _syncTimer;

  // Connectivity service
  late ConnectivityService _connectivityService;
  bool _isSyncingOfflineAttendance = false;
  List<OfflineAttendanceRecord> get _pendingOfflineAttendance => 
      _offlineAttendanceRecords.where((record) => !record.isSynced).toList();

  AppProvider({required this.coreServices, required this.faceService});

  // Getters
  String? get role => _role;
  String? get faceId => _faceId;
  String? get userId => _userId;
  bool get isScanning => _isScanning;
  bool get isBleBroadcasting => _isBroadcasting;
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

  // Offline attendance getters
  List<OfflineAttendanceRecord> get pendingOfflineAttendance => _pendingOfflineAttendance;
  bool get isSyncingOfflineAttendance => _isSyncingOfflineAttendance;
  bool get isNetworkAvailable => _isNetworkAvailable;
  List<OfflineAttendanceRecord> get offlineAttendanceRecords => _offlineAttendanceRecords;
  SyncStatus get syncStatus => _syncStatus;
  bool get hasPendingRecords => _offlineAttendanceRecords.any((record) => !record.isSynced);

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
    // Initialize services
    sessionService = SessionService();
    await sessionService.initialize();
    
    // Initialize connectivity monitoring
    _connectivityService = ConnectivityService();
    await _connectivityService.initialize();
    _connectivityService.addListener(_handleConnectivityChange);
    
    // Initialize offline data
    await _initializeOfflineSupport();
    
    // Start sync timer if auto-sync is enabled
    if (AppConstants.enableAutoSync) {
      _startSyncTimer();
    }
    
    notifyListeners();
  }

  void _handleConnectivityChange(bool isConnected) {
    _isNetworkAvailable = isConnected;
    
    if (isConnected && _pendingOfflineAttendance.isNotEmpty) {
      // Auto-sync when connection is restored
      syncOfflineAttendance();
    }
    
    notifyListeners();
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
    
    // Load any offline attendance records
    await _loadOfflineAttendance();
    
    // Try to sync any pending offline attendance
    if (_pendingOfflineAttendance.isNotEmpty) {
      await syncOfflineAttendance();
    }
    
    // Initialize connectivity listener to sync when online
    _initializeConnectivityListener();
    
    notifyListeners();
  }
  
  void _initializeConnectivityListener() {
    // Simple periodic check for connectivity and sync
    Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        if (_pendingOfflineAttendance.isNotEmpty) {
          // Check connectivity by making a small request
          final testResponse = await http.get(Uri.parse('${AppConstants.baseUrl}/ping'));
          if (testResponse.statusCode == 200) {
            await syncOfflineAttendance();
          }
        }
      } catch (e) {
        // If we can't reach the server, do nothing - we'll try again later
        debugPrint('Connectivity check failed: $e');
      }
    });
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

  // Face verification methods
  Future<VerificationResult> verifyFace() async {
    try {
      _setLoading(true, 'Verifying your identity...');
      
      // Register the face for verification
      final faceId = await faceService.registerFace();
      
      if (faceId == null) {
        return VerificationResult(
          isSuccessful: false, 
          message: 'Could not detect a face clearly. Please try again.'
        );
      }
      
      // Skip actual verification in development mode
      if (kDebugMode && !AppConstants.enforceVerificationInDebug) {
        return VerificationResult(isSuccessful: true, message: 'Verification successful');
      }
      
      // Verify against stored face ID
      final storedFaceId = await _getStoredFaceId();
      
      if (storedFaceId == null || storedFaceId.isEmpty) {
        // If no face ID is stored, this is registration
        await _storeFaceId(faceId);
        return VerificationResult(
          isSuccessful: true, 
          message: 'Face registered successfully'
        );
      } 
      
      // Verify against stored face
      final result = await faceService.verifyFace(storedFaceId);
      
      if (result.isIdentical && result.confidence >= AppConstants.faceConfidenceThreshold) {
        return VerificationResult(
          isSuccessful: true, 
          message: 'Identity verified successfully'
        );
      } else {
        return VerificationResult(
          isSuccessful: false, 
          confidence: result.confidence,
          message: 'Verification failed. Please try again.'
        );
      }
    } catch (e) {
      debugPrint('Face verification error: $e');
      return VerificationResult(
        isSuccessful: false, 
        message: 'An error occurred during verification.'
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> _getStoredFaceId() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'face_id_$_userId');
  }

  Future<void> _storeFaceId(String faceId) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'face_id_$_userId', value: faceId);
    _faceId = faceId; // Update in memory as well
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

      if (_isNetworkAvailable) {
        try {
          // Try to mark attendance online first
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
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                userId: _userId!,
                sessionId: sessionId,
                timestamp: DateTime.now(),
                method: 'BLE+Face',
                program: _currentProgram,
              ),
            );
            _calculateAttendanceStats();
            notifyListeners();
            return;
          }
        } catch (networkError) {
          debugPrint('Network error, saving attendance offline: $networkError');
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
        method: 'BLE+Face',
        program: _currentProgram,
        createdAt: DateTime.now(),
        extraData: {
          'face_verified': true,
          'ble_device_id': device.id,
          'ble_rssi': bleRssi,
          'verification_confidence': verification.confidence,
        },
      );
      
      await addOfflineAttendanceRecord(offlineRecord);
      
      // Also add to local records for immediate UI update
      _attendanceRecords.add(offlineRecord.toAttendanceRecord());
      _calculateAttendanceStats();
      notifyListeners();
      
      // Show offline indicator
      _showOfflineAttendanceMessage();
    } catch (e) {
      debugPrint('Attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  void _showOfflineAttendanceMessage() {
    // This would be implemented with a global key-based SnackBar in a real app
    debugPrint('Attendance saved offline. Will sync when connection is available.');
  }
          sessionId: sessionId,
          method: 'BLE+Face',
          faceVerified: true,
          bleDeviceId: device.id,
          bleRssi: bleRssi,
        );
        
        // Show offline notification
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Attendance saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // QR Attendance marking
  Future<void> markQRAttendance(String sessionId, String lecturerId) async {
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
            _attendanceRecords.add(
              AttendanceRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                userId: _userId!,
                sessionId: sessionId,
                timestamp: DateTime.now(),
                method: 'QR+Face',
                program: _currentProgram,
              ),
            );
            _calculateAttendanceStats();
            notifyListeners();
            return;
          }
        } catch (networkError) {
          debugPrint('Network error, saving QR attendance offline: $networkError');
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
          'lecturer_id': lecturerId,
        },
      );
      
      await addOfflineAttendanceRecord(offlineRecord);
      
      // Also add to local records for immediate UI update
      _attendanceRecords.add(offlineRecord.toAttendanceRecord());
      _calculateAttendanceStats();
      notifyListeners();
      
      // Show offline indicator
      _showOfflineAttendanceMessage();
        );
        
        // Show offline notification
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('QR attendance saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('QR Attendance error: $e');
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

  // Attendance methods
  Future<MarkAttendanceResult> markAttendance(String sessionId, {String method = 'ble'}) async {
    try {
      _setLoading(true, 'Marking attendance...');

      // If network is not available, store attendance locally
      if (!_isNetworkAvailable) {
        final result = await _markOfflineAttendance(sessionId, method: method);
        return result;
      }

      // Online attendance
      final response = await coreServices.markAttendance(
        sessionId: sessionId,
        method: method,
      );

      if (response['success'] == true) {
        // Refresh attendance records
        await fetchAttendanceRecords();
        
        return MarkAttendanceResult(
          isSuccessful: true,
          message: 'Attendance marked successfully',
          isOffline: false,
        );
      } else {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: response['message'] ?? 'Failed to mark attendance',
        );
      }
    } catch (e) {
      debugPrint('Error marking attendance: $e');
      
      // Try offline mode if network error
      if (e is DioException && e.type == DioExceptionType.connectionError) {
        return _markOfflineAttendance(sessionId, method: method);
      }
      
      return MarkAttendanceResult(
        isSuccessful: false,
        message: 'Error: ${e.toString()}',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<MarkAttendanceResult> markQRAttendance(
    String sessionId, 
    String qrData, 
    {String method = 'qr'}
  ) async {
    try {
      _setLoading(true, 'Verifying QR code...');

      // Verify the QR code
      final parts = qrData.split(':');
      if (parts.length != 3 || parts[0] != sessionId) {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: 'Invalid QR code',
        );
      }

      final timestamp = int.tryParse(parts[1]);
      final hmac = parts[2];
      
      if (timestamp == null) {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: 'Invalid QR code format',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp > AppConstants.qrTtlSeconds) {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: 'QR code has expired',
        );
      }

      // If network is not available, store attendance locally
      if (!_isNetworkAvailable) {
        final result = await _markOfflineAttendance(sessionId, method: method);
        return result;
      }

      // Mark attendance online
      final response = await coreServices.markAttendance(
        sessionId: sessionId,
        method: method,
      );

      if (response['success'] == true) {
        // Refresh attendance records
        await fetchAttendanceRecords();
        
        return MarkAttendanceResult(
          isSuccessful: true,
          message: 'QR attendance marked successfully',
          isOffline: false,
        );
      } else {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: response['message'] ?? 'Failed to mark attendance via QR',
        );
      }
    } catch (e) {
      debugPrint('Error marking QR attendance: $e');
      
      // Try offline mode if network error
      if (e is DioException && e.type == DioExceptionType.connectionError) {
        return _markOfflineAttendance(sessionId, method: method);
      }
      
      return MarkAttendanceResult(
        isSuccessful: false,
        message: 'Error: ${e.toString()}',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<MarkAttendanceResult> _markOfflineAttendance(
    String sessionId, 
    {required String method}
  ) async {
    try {
      // Create offline record
      final uuid = const Uuid().v4();
      final now = DateTime.now();
      
      final record = OfflineAttendanceRecord(
        id: uuid,
        sessionId: sessionId,
        studentId: _userId!,
        timestamp: now,
        latitude: 0.0, // Would come from location in a real implementation
        longitude: 0.0,
        method: method,
        isSynced: false,
        createdAt: now,
      );
      
      // Store locally
      final success = await OfflineDataManager.saveOfflineAttendance(record);
      
      if (success) {
        // Update in-memory list
        _offlineAttendanceRecords.add(record);
        _updateSyncStatus();
        
        return MarkAttendanceResult(
          isSuccessful: true,
          message: 'Attendance stored offline. Will sync when connected.',
          isOffline: true,
        );
      } else {
        return MarkAttendanceResult(
          isSuccessful: false,
          message: 'Failed to store attendance offline',
        );
      }
    } catch (e) {
      debugPrint('Error in offline attendance: $e');
      return MarkAttendanceResult(
        isSuccessful: false,
        message: 'Error saving offline: ${e.toString()}',
      );
    }
  }
  
  void _setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    coreServices.stopBleScan();
    _syncTimer?.cancel();
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

  // Manual Attendance Management
  Future<void> markManualAttendance({
    required List<String> studentIds,
    required String sessionId,
    required String program,
  }) async {
    _setLoading(true, 'Marking attendance manually...');
    try {
      final results = await coreServices.markManualAttendance(
        studentIds: studentIds,
        sessionId: sessionId,
      );
      
      if (results) {
        // Refresh attendance records
        await _fetchLecturerData();
      }
    } catch (e) {
      debugPrint('Manual attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> removeAttendanceRecord(String recordId) async {
    _setLoading(true, 'Removing attendance record...');
    try {
      final success = await coreServices.removeAttendanceRecord(recordId);
      if (success) {
        // Remove from local state
        _attendanceRecords.removeWhere((record) => record.id == recordId);
        _calculateAttendanceStats();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Remove attendance error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Offline Attendance Methods
  Future<void> saveOfflineAttendance({
    required String sessionId,
    required String method,
    required bool faceVerified,
    String? bleDeviceId,
    int? bleRssi,
  }) async {
    // Create an offline attendance record
    final offlineRecord = OfflineAttendanceRecord(
      id: Utils.generateSecureKey(),
      userId: _userId!,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      method: method,
      faceVerified: faceVerified,
      program: _currentProgram,
      bleDeviceId: bleDeviceId,
      bleRssi: bleRssi,
    );

    // Add to local state
    _pendingOfflineAttendance.add(offlineRecord);
    notifyListeners();

    // Save to SharedPreferences
    await _persistOfflineAttendance();

    // Add to local attendance records so it shows up in the UI
    _attendanceRecords.add(
      AttendanceRecord(
        id: offlineRecord.id,
        userId: offlineRecord.userId,
        sessionId: offlineRecord.sessionId,
        timestamp: offlineRecord.timestamp,
        method: "${offlineRecord.method} (Offline)",
        program: offlineRecord.program,
      ),
    );
    _calculateAttendanceStats();
    notifyListeners();
  }

  Future<void> _persistOfflineAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = _pendingOfflineAttendance
          .map((record) => jsonEncode(record.toJson()))
          .toList();
      await prefs.setStringList('offline_attendance', recordsJson);
    } catch (e) {
      debugPrint('Error saving offline attendance: $e');
    }
  }

  Future<void> _loadOfflineAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('offline_attendance') ?? [];
      
      _pendingOfflineAttendance = recordsJson
          .map((json) => OfflineAttendanceRecord.fromJson(
              jsonDecode(json) as Map<String, dynamic>))
          .toList();
          
      // Also add these to the UI
      for (final record in _pendingOfflineAttendance) {
        final attendanceRecord = AttendanceRecord(
          id: record.id,
          userId: record.userId,
          sessionId: record.sessionId,
          timestamp: record.timestamp,
          method: "${record.method} (Offline)",
          program: record.program,
        );
        
        // Only add if not already in the list
        if (!_attendanceRecords.any((r) => r.id == record.id)) {
          _attendanceRecords.add(attendanceRecord);
        }
      }
      
      _calculateAttendanceStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading offline attendance: $e');
    }
  }

  Future<void> syncOfflineAttendance() async {
    if (_pendingOfflineAttendance.isEmpty || _isSyncingOfflineAttendance) {
      return;
    }

    _isSyncingOfflineAttendance = true;
    _setLoading(true, 'Syncing offline attendance...');
    notifyListeners();

    try {
      // Process each record one by one
      List<OfflineAttendanceRecord> successfulRecords = [];

      for (final record in _pendingOfflineAttendance) {
        try {
          bool success = false;
          
          if (record.method == 'BLE+Face') {
            success = await coreServices.markAttendance(
              userId: record.userId,
              sessionId: record.sessionId,
              faceVerified: record.faceVerified,
              bleDeviceId: record.bleDeviceId ?? 'unknown',
              bleRssi: record.bleRssi ?? -100,
            );
          } else if (record.method == 'QR+Face') {
            success = await coreServices.markQRAttendance(
              userId: record.userId,
              sessionId: record.sessionId,
              faceVerified: record.faceVerified,
            );
          }

          if (success) {
            successfulRecords.add(record);
            
            // Update the corresponding record in the UI (remove offline tag)
            final index = _attendanceRecords.indexWhere((r) => r.id == record.id);
            if (index != -1) {
              _attendanceRecords[index] = AttendanceRecord(
                id: record.id,
                userId: record.userId,
                sessionId: record.sessionId,
                timestamp: record.timestamp,
                method: record.method,
                program: record.program,
              );
            }
          }
        } catch (e) {
          debugPrint('Error syncing record ${record.id}: $e');
        }
      }

      // Remove synced records
      _pendingOfflineAttendance.removeWhere(
        (record) => successfulRecords.any((r) => r.id == record.id),
      );

      // Update persisted records
      await _persistOfflineAttendance();
      
      _calculateAttendanceStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error during offline sync: $e');
    } finally {
      _isSyncingOfflineAttendance = false;
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchAttendanceRecords(String sessionId) async {
    _setLoading(true, 'Loading attendance records...');
    try {
      final records = await coreServices.getSessionAttendance(sessionId);
      // Update only records for this session
      _attendanceRecords = _attendanceRecords
          .where((r) => r.sessionId != sessionId)
          .toList()
        ..addAll(records);
      _calculateAttendanceStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch attendance records error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Emergency Exit Methods
  Future<bool> requestEmergencyExit(String reason) async {
    _setLoading(true, 'Processing emergency exit...');
    try {
      final result = await coreServices.requestEmergencyExit(
        userId: _userId!,
        reason: reason,
      );
      
      // Add emergency exit result
      _lastExitResult = ExitResult(
        allowed: result.allowed,
        message: result.message,
        studentName: _getCurrentUser()?.name,
      );
      
      // Add notification
      _notifications.insert(
        0,
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: result.allowed ? AppConstants.notifExitAllowed : AppConstants.notifExitDenied,
          title: result.allowed ? 'Emergency Exit Approved' : 'Emergency Exit Pending',
          body: result.message,
          timestamp: DateTime.now(),
        ),
      );
      
      notifyListeners();
      return result.allowed;
    } catch (e) {
      debugPrint('Emergency exit error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Offline attendance methods
  Future<void> _initializeOfflineSupport() async {
    try {
      // Load any existing offline attendance records
      _offlineAttendanceRecords = await OfflineDataManager.getOfflineAttendanceRecords();
      
      // Update sync status
      _updateSyncStatus();
      
      debugPrint('Loaded ${_offlineAttendanceRecords.length} offline attendance records');
    } catch (e) {
      debugPrint('Error initializing offline support: $e');
    }
  }
  
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: AppConstants.offlineSyncInterval), 
      (_) {
        if (_isNetworkAvailable && _pendingOfflineAttendance.isNotEmpty) {
          syncOfflineAttendance();
        }
      }
    );
  }
  
  Future<bool> syncOfflineAttendance() async {
    if (_isSyncingOfflineAttendance || _pendingOfflineAttendance.isEmpty) {
      return false;
    }
    
    _isSyncingOfflineAttendance = true;
    _syncStatus = _syncStatus.copyWith(
      isInProgress: true,
      lastSyncAttempt: DateTime.now(),
    );
    notifyListeners();
    
    try {
      final successfulIds = <String>[];
      final failedIds = <String>[];
      
      // Process each record
      for (final record in _pendingOfflineAttendance) {
        try {
          // Attempt to sync the record
          final success = await _syncOfflineRecord(record);
          
          if (success) {
            successfulIds.add(record.id);
          } else {
            failedIds.add(record.id);
          }
        } catch (e) {
          failedIds.add(record.id);
          debugPrint('Error syncing record ${record.id}: $e');
        }
      }
      
      // Remove synced records from storage
      if (successfulIds.isNotEmpty) {
        await OfflineDataManager.removeSyncedRecords(successfulIds);
        
        // Update in-memory records
        _offlineAttendanceRecords = _offlineAttendanceRecords
            .where((r) => !successfulIds.contains(r.id))
            .toList();
      }
      
      // Update sync status
      _syncStatus = _syncStatus.copyWith(
        isInProgress: false,
        lastSyncCompletion: DateTime.now(),
        successCount: _syncStatus.successCount + successfulIds.length,
        failureCount: _syncStatus.failureCount + failedIds.length,
        isError: failedIds.isNotEmpty,
      );
      
      notifyListeners();
      return successfulIds.isNotEmpty;
    } catch (e) {
      debugPrint('Sync error: $e');
      
      _syncStatus = _syncStatus.copyWith(
        isInProgress: false,
        lastSyncCompletion: DateTime.now(),
        isError: true,
        errorMessage: e.toString(),
      );
      
      notifyListeners();
      return false;
    } finally {
      _isSyncingOfflineAttendance = false;
    }
  }
  
  Future<bool> _syncOfflineRecord(OfflineAttendanceRecord record) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        AppConstants.attendanceEndpoint,
        data: {
          'session_id': record.sessionId,
          'student_id': record.studentId,
          'timestamp': record.timestamp.toIso8601String(),
          'latitude': record.latitude,
          'longitude': record.longitude,
          'method': record.method,
          'captured_offline': true,
          'offline_id': record.id,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${await sessionService.getAccessToken()}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing record: $e');
      return false;
    }
  }
  
  void _updateSyncStatus() {
    final pendingCount = _pendingOfflineAttendance.length;
    
    _syncStatus = _syncStatus.copyWith(
      pendingCount: pendingCount,
    );
    
    notifyListeners();
  }

  // BLE Attendance Methods
  Future<bool> startBleAttendanceBeacon({
    required String sessionId,
    required String program,
  }) async {
    try {
      final session = await sessionService.getSessionById(sessionId);
      if (session == null) {
        return false;
      }
      
      // Start BLE advertising
      final bleData = session.toBlePayload();
      await coreServices.startBleAdvertising(
        bleData, 
        AppConstants.bleServiceUuid,
        AppConstants.bleCharacteristicUuid,
      );
      
      // Update state
      _isBroadcasting = true;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Error starting BLE beacon: $e');
      return false;
    }
  }
  
  Future<bool> stopBleAttendanceBeacon() async {
    try {
      await coreServices.stopBleAdvertising();
      
      // Update state
      _isBroadcasting = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Error stopping BLE beacon: $e');
      return false;
    }
  }
  
  Future<bool> markAttendanceByQr({
    required String sessionId,
    required String userId,
    required String program,
  }) async {
    try {
      final result = await coreServices.markAttendance(
        sessionId: sessionId, 
        userId: userId,
        method: 'qr',
        program: program,
      );
      
      if (result) {
        // Update local attendance records
        await _fetchAttendanceRecords(userId);
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      print('Error marking attendance by QR: $e');
      return false;
    }
  }
  
  Future<bool> markAttendanceByBle({
    required String sessionId,
    required String userId,
    required String program,
  }) async {
    try {
      final result = await coreServices.markAttendance(
        sessionId: sessionId, 
        userId: userId,
        method: 'ble',
        program: program,
      );
      
      if (result) {
        // Update local attendance records
        await _fetchAttendanceRecords(userId);
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      print('Error marking attendance by BLE: $e');
      
      // Handle offline mode
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        final success = await _saveOfflineAttendance(
          sessionId: sessionId,
          userId: userId,
          method: 'ble',
          program: program,
        );
        
        return success;
      }
      
      return false;
    }
  }
  
  Future<bool> markAttendanceByFace({
    required String sessionId,
    required String userId,
    required String program,
    required String faceId,
  }) async {
    try {
      // Verify face first
      final isVerified = await faceService.verifyFace(
        userId: userId,
        faceId: faceId,
        confidenceThreshold: AppConstants.faceConfidenceThreshold,
      );
      
      if (!isVerified) {
        return false;
      }
      
      // Mark attendance after verification
      final result = await coreServices.markAttendance(
        sessionId: sessionId, 
        userId: userId,
        method: 'face',
        program: program,
      );
      
      if (result) {
        // Update local attendance records
        await _fetchAttendanceRecords(userId);
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      print('Error marking attendance by face: $e');
      
      // Handle offline mode
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        final success = await _saveOfflineAttendance(
          sessionId: sessionId,
          userId: userId,
          method: 'face',
          program: program,
        );
        
        return success;
      }
      
      return false;
    }
  }
  
  Future<bool> _saveOfflineAttendance({
    required String sessionId,
    required String userId,
    required String method,
    required String program,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing offline records
      final offlineDataJson = prefs.getString(AppConstants.offlineAttendanceKey) ?? '[]';
      final List<dynamic> offlineData = jsonDecode(offlineDataJson);
      
      // Add new record
      offlineData.add({
        'session_id': sessionId,
        'user_id': userId,
        'method': method,
        'program': program,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Limit the number of offline records
      if (offlineData.length > AppConstants.maxOfflineRecords) {
        offlineData.removeRange(0, offlineData.length - AppConstants.maxOfflineRecords);
      }
      
      // Save back to shared preferences
      await prefs.setString(AppConstants.offlineAttendanceKey, jsonEncode(offlineData));
      
      // Schedule sync if auto-sync is enabled
      if (AppConstants.enableAutoSync) {
        _scheduleOfflineSync();
      }
      
      return true;
    } catch (e) {
      print('Error saving offline attendance: $e');
      return false;
    }
  }
  
  Future<void> _scheduleOfflineSync() async {
    // Set a timer to sync data
    Timer(Duration(minutes: AppConstants.offlineSyncInterval), () {
      syncOfflineAttendance();
    });
  }
  
  Future<bool> syncOfflineAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get offline records
      final offlineDataJson = prefs.getString(AppConstants.offlineAttendanceKey) ?? '[]';
      final List<dynamic> offlineData = jsonDecode(offlineDataJson);
      
      if (offlineData.isEmpty) {
        return true; // Nothing to sync
      }
      
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        return false; // No internet connection
      }
      
      // Try to sync each record
      final successfulSyncs = <int>[];
      
      for (int i = 0; i < offlineData.length; i++) {
        final record = offlineData[i];
        
        try {
          final result = await coreServices.markAttendance(
            sessionId: record['session_id'],
            userId: record['user_id'],
            method: '${record['method']}_offline',
            program: record['program'],
          );
          
          if (result) {
            successfulSyncs.add(i);
          }
        } catch (e) {
          print('Error syncing record: $e');
          // Continue with next record
        }
      }
      
      // Remove successfully synced records
      for (int i = successfulSyncs.length - 1; i >= 0; i--) {
        offlineData.removeAt(successfulSyncs[i]);
      }
      
      // Save remaining records
      await prefs.setString(AppConstants.offlineAttendanceKey, jsonEncode(offlineData));
      
      // Schedule next sync if there are still records
      if (offlineData.isNotEmpty && AppConstants.enableAutoSync) {
        _scheduleOfflineSync();
      }
      
      return successfulSyncs.isNotEmpty;
    } catch (e) {
      print('Error syncing offline attendance: $e');
      return false;
    }
  }
  
  // Exit Management Methods
  // This method was removed as it was a duplicate of the one at line 1231
  
  Future<ExitResult> verifyExitRequest({
    required String universityId,
    required String gateId,
  }) async {
    try {
      // Check if there's an approved leave request for this user
      final leaves = await coreServices.fetchApprovedLeavesByUser(universityId);
      final now = DateTime.now();
      
      bool hasApprovedLeave = leaves.any((leave) => 
        leave.startDate.isBefore(now) && leave.endDate.isAfter(now)
      );
      
      // Check if there's an emergency exit request
      final hasEmergencyRequest = await coreServices.checkEmergencyExitRequest(universityId);
      
      if (!hasApprovedLeave && !hasEmergencyRequest) {
        return ExitResult(
          allowed: false,
          message: AppConstants.unauthorizedExitError,
          studentName: await _getStudentName(universityId),
          studentPhotoUrl: null,
        );
      }
      
      // Record the exit
      final exitType = hasApprovedLeave ? 'approved_leave' : 'emergency';
      final result = await coreServices.recordExit(
        userId: universityId,
        gateId: gateId,
        exitType: exitType,
      );
      
      if (!result) {
        return ExitResult(
          allowed: false,
          message: 'Failed to record exit. Please try again.',
          studentName: await _getStudentName(universityId),
          studentPhotoUrl: null,
        );
      }
      
      return ExitResult(
        allowed: true,
        message: hasApprovedLeave 
            ? 'Approved leave verified. Exit permitted.' 
            : 'Emergency exit request verified.',
        studentName: await _getStudentName(universityId),
        studentPhotoUrl: null,
      );
    } catch (e) {
      print('Error verifying exit: $e');
      return ExitResult(
        allowed: false,
        message: 'Error: $e',
        studentName: null,
        studentPhotoUrl: null,
      );
    }
  }
  
  Future<String?> _getStudentName(String universityId) async {
    try {
      final user = await coreServices.getUserById(universityId);
      return user?.name;
    } catch (e) {
      return null;
    }
  }
  
  Future<List<LeaveRequest>> fetchApprovedLeaves() async {
    try {
      final leaves = await coreServices.fetchAllApprovedLeaves();
      return leaves;
    } catch (e) {
      print('Error fetching approved leaves: $e');
      return [];
    }
  }
}

}
