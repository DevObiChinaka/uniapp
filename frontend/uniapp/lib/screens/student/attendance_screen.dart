import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'face_verification_screen.dart';
import 'qr_attendance_screen.dart';

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

      // Get lecturer's location from active session
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
      final double lecturerLat = session.geofence!.latitude;
      final double lecturerLng = session.geofence!.longitude;
      debugPrint(
        '[AttendanceScreen] Lecturer geofence location: $lecturerLat, $lecturerLng',
      );

      // Calculate distance between student and lecturer
      double distanceInMeters = Geolocator.distanceBetween(
        studentPosition.latitude,
        studentPosition.longitude,
        lecturerLat,
        lecturerLng,
      );
      debugPrint(
        '[AttendanceScreen] Distance to lecturer: ${distanceInMeters.toStringAsFixed(2)} meters',
      );

      if (mounted)
        setState(() {
          _isInProximity = distanceInMeters <= 50.0;
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
      final userId = user?.universityId;
      if (activeSession == null || userId == null) {
        throw Exception('SESSION_OR_USER_MISSING: Cannot mark attendance.');
      }
      final success = await appProvider.coreServices.markAttendance(
        userId: userId,
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
      debugPrint('[AttendanceScreen] Fetching active session...');
      await provider.fetchActiveSession();
      debugPrint('[AttendanceScreen] Fetching attendance history...');
      await provider.fetchAttendanceHistory();
      _errorMessage = null;
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
            tooltip: 'View Full History',
            onPressed: () {
              // TODO: Navigate to full history screen
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
                final recentAttendance =
                    provider.attendanceRecords.take(5).toList();

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeSession != null)
                          Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Course: ${activeSession.courseId ?? 'N/A'}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
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
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.fingerprint),
                                    label:
                                        _isMarkingAttendance
                                            ? Text('Marking...')
                                            : !_isInProximity
                                            ? Text('Not in proximity')
                                            : Text('Mark Attendance'),
                                    onPressed:
                                        !_isInProximity || _isMarkingAttendance
                                            ? null
                                            : () async {
                                              await _markAttendance();
                                            },
                                  ),
                                  if (!_isInProximity)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'You must be within 50 meters of the lecturer to mark attendance.',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  if (_markAttendanceError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _markAttendanceError!,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
                                      'No active session available for your program/level.',
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
                        Text(
                          'Recent Attendance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        if (recentAttendance.isNotEmpty)
                          ...recentAttendance.map(
                            (record) => Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                title: Text('Session: ${record.sessionId}'),
                                subtitle: Text(
                                  'Time: ${record.timestamp.toLocal().toString().substring(0, 19)}',
                                ),
                                trailing: Text(
                                  'Marked',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ),
                          )
                        else
                          Text('No recent attendance records.'),
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
