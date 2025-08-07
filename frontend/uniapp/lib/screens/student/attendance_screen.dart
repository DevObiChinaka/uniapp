// ...existing code...
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/course.dart';
import 'package:geolocator/geolocator.dart';
import 'qr_attendance_screen.dart';
import 'face_verification_screen.dart';
import 'attendance_history_screen.dart';

// ...removed local Course class, using shared model instead...

Future<Course?> _fetchCourseDetails(BuildContext context, String courseId) {
  if (courseId.isEmpty) return Future.value(null);
  try {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return provider.coreServices.getCourse(courseId);
  } catch (e) {
    debugPrint('[AttendanceScreen] Course fetch error: $e');
    return Future.value(null);
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isInProximity = false;

  Future<void> _checkProximity() async {
    try {
      debugPrint('[AttendanceScreen] Checking proximity to lecturer...');
      // Request location permission if not already granted
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted)
            setState(() {
              _isInProximity = false;
            });
          debugPrint('[AttendanceScreen] Location permission denied.');
          return;
        }
      }

      // Get student's current location
      Position studentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
        '[AttendanceScreen] Student location: ${studentPosition.latitude}, ${studentPosition.longitude}',
      );

      // Get lecturer's location and geofence radius from active session
      final provider = Provider.of<AppProvider>(context, listen: false);
      final session = provider.activeSession;
      if (session == null || session.geofence == null) {
        if (mounted)
          setState(() {
            _isInProximity = false;
          });
        debugPrint(
          '[AttendanceScreen] Lecturer geofence location not available.',
        );
        return;
      }
      final double geofenceLat = session.geofence!.latitude;
      final double geofenceLng = session.geofence!.longitude;
      final double geofenceRadius = session.geofence!.radius; // meters
      debugPrint(
        '[AttendanceScreen] Geofence location: $geofenceLat, $geofenceLng, radius: $geofenceRadius',
      );

      // Calculate distance between student and geofence center
      double distanceInMeters = Geolocator.distanceBetween(
        studentPosition.latitude,
        studentPosition.longitude,
        geofenceLat,
        geofenceLng,
      );
      debugPrint(
        '[AttendanceScreen] Distance to geofence center: ${distanceInMeters.toStringAsFixed(2)} meters',
      );

      if (mounted)
        setState(() {
          _isInProximity = distanceInMeters <= geofenceRadius;
        });
    } catch (e) {
      debugPrint('[AttendanceScreen] Proximity check error: $e');
      if (mounted)
        setState(() {
          _isInProximity = false;
        });
    }
  }

  bool _isMarkingAttendance = false;
  String? _markAttendanceError;
  bool _isMarked = false;

  Future<void> _markAttendance() async {
    if (mounted)
      setState(() {
        _isMarkingAttendance = true;
        _markAttendanceError = null;
      });
    try {
      debugPrint('[AttendanceScreen] Starting face scan...');
      // Navigate to FaceVerificationPage and await result
      final faceVerified = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => FaceVerificationScreen()));
      if (faceVerified != true) {
        throw Exception('FACE_VERIFICATION_FAILED: Face scan unsuccessful.');
      }

      debugPrint('[AttendanceScreen] Marking attendance via backend...');
      final provider = Provider.of<AppProvider>(context, listen: false);
      // Get current location for attendance
      Position? studentPosition;
      try {
        studentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        debugPrint('[AttendanceScreen] Location fetch error: $e');
      }
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final activeSession = appProvider.activeSession;
      final user = appProvider.getCurrentUser();
      final userId = user?.id;
      if (activeSession == null || userId == null) {
        throw Exception('SESSION_OR_USER_MISSING: Cannot mark attendance.');
      }
      final success = await appProvider.coreServices.markAttendance(
        userId: userId.toString(), // Use PK (id) for attendance marking
        sessionId: activeSession.id,
        faceVerified: true,
        latitude: studentPosition?.latitude,
        longitude: studentPosition?.longitude,
      );
      if (!success) {
        throw Exception('Failed to mark attendance on server');
      }

      // Refresh attendance history after marking
      await provider.fetchAttendanceHistory();

      // Re-check marked status after refresh
      bool marked = provider.attendanceHistory.any(
        (record) =>
            record.sessionId == activeSession.id &&
            record.period == activeSession.currentPeriod,
      );
      debugPrint(
        '[AttendanceScreen] After marking attendance - Is marked: $marked',
      );
      if (mounted) {
        setState(() {
          _isMarked = marked;
        });
      }

      debugPrint('[AttendanceScreen] Attendance marked successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked successfully!')),
      );
    } catch (e) {
      debugPrint('[AttendanceScreen] Mark attendance error: $e');
      if (mounted)
        setState(() {
          _markAttendanceError = e.toString();
        });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_markAttendanceError ?? 'Error marking attendance'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted)
        setState(() {
          _isMarkingAttendance = false;
        });
    }
  }

  Future<void>? _fetchFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _fetchAttendanceData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProximity();
    });
  }

  Future<void> _fetchAttendanceData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    try {
      debugPrint('[AttendanceScreen] Fetching latest user profile...');
      await provider.fetchProfile(); // Ensure user PK is up-to-date
      debugPrint('[AttendanceScreen] Fetching active session...');
      await provider.fetchActiveSession();
      debugPrint('[AttendanceScreen] Fetching attendance history...');
      await provider.fetchAttendanceHistory();
      _errorMessage = null;

      // Check marked status immediately after fetching
      final activeSession = provider.activeSession;
      bool marked = false;
      if (activeSession != null) {
        debugPrint(
          '[AttendanceScreen] Checking if attendance is marked for session: ${activeSession.id}, period: ${activeSession.currentPeriod}',
        );
        debugPrint(
          '[AttendanceScreen] Available attendance records: ${provider.attendanceHistory.length}',
        );
        for (var record in provider.attendanceHistory) {
          debugPrint(
            '[AttendanceScreen] Record: sessionId=${record.sessionId}, period=${record.period}',
          );
        }
        marked = provider.attendanceHistory.any(
          (record) =>
              record.sessionId == activeSession.id &&
              record.period == activeSession.currentPeriod,
        );
        debugPrint('[AttendanceScreen] Is marked: $marked');
      }
      if (mounted) {
        setState(() {
          _isMarked = marked;
        });
      }
    } catch (e) {
      debugPrint('[AttendanceScreen] Error: $e');
      if (mounted)
        setState(() {
          _errorMessage = 'Failed to load attendance data.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            tooltip: 'View Attendance History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AttendanceHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.qr_code_scanner),
        label: Text('Scan QR'),
        onPressed: () {
          final provider = Provider.of<AppProvider>(context, listen: false);
          final universityId = provider.userId ?? '';
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => QRAttendanceScreen(universityId: universityId),
            ),
          );
        },
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          if (mounted)
            setState(() {
              _fetchFuture = _fetchAttendanceData();
            });
          await _fetchFuture;
        },
        child: FutureBuilder<void>(
          future: _fetchFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (_errorMessage != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Consumer<AppProvider>(
              builder: (context, provider, _) {
                final activeSession = provider.activeSession;

                // Use _isMarked for button and status
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeSession != null)
                          FutureBuilder<Course?>(
                            future: _fetchCourseDetails(
                              context,
                              activeSession.courseId ?? '',
                            ),
                            builder: (context, snapshot) {
                              final course = snapshot.data;
                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Course Code: ${course?.code ?? activeSession.courseId ?? 'N/A'}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                      if (course?.name != null &&
                                          course!.name.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            course.name,
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                          ),
                                        ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Lecturer: ${activeSession.lecturerUsername}',
                                      ),
                                      Text(
                                        'Time: ${activeSession.startTime.toLocal().toString().substring(0, 19)}',
                                      ),
                                      Text(
                                        'Period: ${activeSession.currentPeriod}',
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            _isMarked
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color:
                                                _isMarked
                                                    ? Colors.green
                                                    : Colors.grey,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            _isMarked
                                                ? 'Attendance marked for this period'
                                                : 'Not marked for this period',
                                            style: TextStyle(
                                              color:
                                                  _isMarked
                                                      ? Colors.green
                                                      : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        icon: Icon(Icons.fingerprint),
                                        label:
                                            _isMarkingAttendance
                                                ? Text('Marking...')
                                                : !_isInProximity
                                                ? Text('Not in proximity')
                                                : Text('Mark Attendance'),
                                        onPressed:
                                            !_isInProximity ||
                                                    _isMarkingAttendance ||
                                                    _isMarked
                                                ? null
                                                : () async {
                                                  await _markAttendance();
                                                },
                                      ),
                                      if (!_isInProximity)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            'You must be within 50 meters of the lecturer to mark attendance.',
                                            style: TextStyle(
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      if (_markAttendanceError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            _markAttendanceError!,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Card(
                            color: Colors.grey[100],
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      provider.sessions.isNotEmpty
                                          ? 'Sessions are available but none are currently active. Please wait for your lecturer to start the session.'
                                          : 'No sessions found for your program/level.',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Add a spacer and quick action buttons
                        const SizedBox(height: 24),

                        // Quick actions card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Actions',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const AttendanceHistoryScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.history),
                                        label: const Text('View History'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
