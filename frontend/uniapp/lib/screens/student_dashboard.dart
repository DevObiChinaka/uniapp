// student_dashboard.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/utils/utils.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart' as routes;

class StudentDashboard extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String universityId;
  final String token;
  final String role;

  const StudentDashboard({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.universityId,
    required this.token,
    required this.role,
  });

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Attendance', 'Leave', 'Exit', 'Dashboard'];
  MobileScannerController? _qrController;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      setState(() {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
        );
        _cameraController!.initialize();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qrController?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          toolbarHeight: 110,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFa1c4fd), Color(0xFFc2e9fb)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: FutureBuilder<String?>(
                        future: SharedPreferences.getInstance().then(
                          (prefs) => prefs.getString('profile_image_path'),
                        ),
                        builder: (context, snapshot) {
                          final imagePath = snapshot.data;
                          final hasImage =
                              imagePath != null && File(imagePath).existsSync();
                          return GestureDetector(
                            onTap: () {
                              context.push(
                                routes.AppRoutes.editProfile,
                                extra: {
                                  'firstName': widget.firstName,
                                  'lastName': widget.lastName,
                                  'universityId': widget.universityId,
                                  'role': widget.role,
                                },
                              );
                            },
                            child: CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  hasImage ? FileImage(File(imagePath)) : null,
                              backgroundColor: Colors.white,
                              child:
                                  hasImage
                                      ? null
                                      : Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Colors.blueGrey,
                                      ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome,',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.blueGrey[700],
                            ),
                          ),
                          Text(
                            '${widget.firstName} ${widget.lastName}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          Text(
                            'ID: ${widget.universityId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blueGrey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.blueGrey),
                      tooltip: 'Logout',
                      onPressed: () async {
                        final shouldLogout =
                            await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text(
                                      'Are you sure you want to logout?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('CANCEL'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('LOGOUT'),
                                      ),
                                    ],
                                  ),
                            ) ??
                            false;

                        if (shouldLogout) {
                          final provider = Provider.of<AppProvider>(
                            context,
                            listen: false,
                          );
                          final success = await provider.logout();

                          if (success && mounted) {
                            // Navigate to login screen
                            context.go(routes.AppRoutes.login);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          title: const Text(
            '',
          ), // Empty title to create space for flexibleSpace content
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceTab(appProvider),
              _buildLeaveTab(appProvider),
              _buildExitTab(appProvider),
              _buildDashboardTab(appProvider),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.08),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Color(0xFFa1c4fd),
              borderRadius: BorderRadius.circular(32),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.blueGrey[400],
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(AppProvider appProvider) {
    final activeSession = appProvider.activeSession;
    final attendanceRecords = appProvider.attendanceRecords;
    final isLoading = appProvider.isLoading;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeSession != null) ...[
            Card(
              color: Colors.blue[50],
              child: ListTile(
                title: Text('Active Session: ${activeSession.program}'),
                subtitle: Text(
                  'Started: ${Utils.formatDateTime(activeSession.startTime)}',
                ),
                trailing: Chip(
                  label: Text('Live'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_scanner),
              label: Text('Scan QR for Attendance'),
              onPressed:
                  isLoading
                      ? null
                      : () async {
                        _startQRAttendanceScanner(appProvider);
                      },
            ),
            SizedBox(height: 16),
          ] else ...[
            Center(
              child: Text(
                'No active session. Please wait for a session to start.',
              ),
            ),
            SizedBox(height: 16),
          ],
          Text(
            'Recent Attendance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Expanded(
            child:
                attendanceRecords.isEmpty
                    ? Center(child: Text('No attendance records yet.'))
                    : ListView.builder(
                      itemCount: attendanceRecords.length,
                      itemBuilder: (context, index) {
                        final record =
                            attendanceRecords[attendanceRecords.length -
                                1 -
                                index];
                        return ListTile(
                          leading: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(record.program ?? 'Session'),
                          subtitle: Text(
                            Utils.formatDateTime(record.timestamp),
                          ),
                          trailing: Text(record.method),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTab(AppProvider appProvider) {
    final leaveRequests = appProvider.leaveRequests;
    final isSubmitting = appProvider.isSubmittingLeave;
    final leaveFormKey = GlobalKey<FormState>();
    DateTime? startDate;
    DateTime? endDate;
    String reason = '';

    void submitLeave() async {
      if (leaveFormKey.currentState!.validate()) {
        leaveFormKey.currentState!.save();
        if (startDate == null || endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select start and end dates.')),
          );
          return;
        }
        await appProvider.submitLeaveRequest(startDate!, endDate!, reason);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Leave request submitted.')));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Submit Leave Request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Form(
            key: leaveFormKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap:
                            isSubmitting
                                ? null
                                : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null) {
                                    startDate = picked;
                                    (context as Element).markNeedsBuild();
                                  }
                                },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            startDate == null
                                ? 'Select'
                                : Utils.formatDate(startDate!),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap:
                            isSubmitting
                                ? null
                                : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: startDate ?? DateTime.now(),
                                    firstDate: startDate ?? DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null) {
                                    endDate = picked;
                                    (context as Element).markNeedsBuild();
                                  }
                                },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            endDate == null
                                ? 'Select'
                                : Utils.formatDate(endDate!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter a reason'
                              : null,
                  onSaved: (value) => reason = value ?? '',
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitLeave,
                  child:
                      isSubmitting
                          ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text('Submit'),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'My Leave Requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Expanded(
            child:
                leaveRequests.isEmpty
                    ? Center(child: Text('No leave requests yet.'))
                    : ListView.builder(
                      itemCount: leaveRequests.length,
                      itemBuilder: (context, index) {
                        final leave =
                            leaveRequests[leaveRequests.length - 1 - index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.event_note),
                            title: Text(
                              '${Utils.formatDate(leave.startDate)} - ${Utils.formatDate(leave.endDate)}',
                            ),
                            subtitle: Text(leave.reason),
                            trailing: Chip(
                              label: Text(leave.status.value),
                              backgroundColor:
                                  leave.status == 'approved'
                                      ? Colors.green[100]
                                      : leave.status == 'denied'
                                      ? Colors.red[100]
                                      : Colors.orange[100],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitTab(AppProvider appProvider) {
    final isProcessing = appProvider.isExitProcessing;
    final exitResult = appProvider.lastExitResult;
    String? lastScannedCode;

    void onDetect(BarcodeCapture capture) async {
      if (isProcessing) return;
      final code = capture.barcodes.firstOrNull?.rawValue;
      if (code != null && code != lastScannedCode) {
        lastScannedCode = code;
        await appProvider.processGateExit(code);
        (context as Element).markNeedsBuild();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gate Exit', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Expanded(
            child: Card(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _qrController ??= MobileScannerController(),
                    onDetect: onDetect,
                  ),
                  if (isProcessing)
                    Container(
                      color: Colors.black45,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.warning_amber, color: Colors.white),
            label: Text('Request Emergency Exit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _requestEmergencyExit(appProvider),
          ),
          SizedBox(height: 16),
          if (exitResult != null)
            Card(
              color: exitResult.allowed ? Colors.green[50] : Colors.red[50],
              child: ListTile(
                leading: Icon(
                  exitResult.allowed ? Icons.check_circle : Icons.cancel,
                  color: exitResult.allowed ? Colors.green : Colors.red,
                ),
                title: Text(
                  exitResult.allowed ? 'Exit Approved' : 'Exit Denied',
                ),
                subtitle: Text(exitResult.message),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => appProvider.clearExitResult(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(AppProvider appProvider) {
    final attendanceRecords = appProvider.attendanceRecords;
    final totalSessions = appProvider.totalSessions;
    final attendanceCount = attendanceRecords.length;
    final attendancePercent =
        totalSessions > 0 ? (attendanceCount / totalSessions) * 100 : 0.0;
    final flagged = attendancePercent < (appProvider.attendanceThreshold * 100);
    final nextSession = appProvider.activeSession;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            color: Colors.blue[50],
            child: ListTile(
              leading: Icon(Icons.bar_chart, color: Colors.blue),
              title: Text('Attendance Rate'),
              subtitle: Text('$attendanceCount of $totalSessions sessions'),
              trailing: Text(
                '${attendancePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: flagged ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (flagged)
            Card(
              color: Colors.orange[50],
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text('Warning: Low Attendance'),
                subtitle: Text(
                  'Your attendance is below the required threshold.',
                ),
              ),
            ),
          if (nextSession != null)
            Card(
              color: Colors.green[50],
              child: ListTile(
                leading: Icon(Icons.event, color: Colors.green),
                title: Text('Active Session'),
                subtitle: Text(
                  '${nextSession.program} - Started: ${Utils.formatDateTime(nextSession.startTime)}',
                ),
              ),
            ),
          SizedBox(height: 16),
          Text(
            'Recent Attendance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ...attendanceRecords.reversed
              .take(5)
              .map(
                (record) => ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text(record.program ?? 'Session'),
                  subtitle: Text(Utils.formatDateTime(record.timestamp)),
                  trailing: Text(record.method),
                ),
              ),
        ],
      ),
    );
  }

  void _startQRAttendanceScanner(AppProvider appProvider) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('QR Attendance Scanner'),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              height: 300,
              width: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _qrController ??= MobileScannerController(),
                    onDetect: (capture) async {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final barcode = barcodes.first;
                        if (barcode.rawValue != null) {
                          // Close the dialog first
                          Navigator.pop(context);

                          // Process the QR code for attendance
                          await _processQRAttendance(
                            barcode.rawValue!,
                            appProvider,
                          );
                        }
                      }
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    width: 200,
                    height: 200,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _processQRAttendance(
    String qrData,
    AppProvider appProvider,
  ) async {
    try {
      // Parse the QR data to get session information
      Map<String, dynamic> sessionData = {};
      try {
        sessionData = Map<String, dynamic>.from(jsonDecode(qrData));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid QR code format')));
        return;
      }

      // Validate QR data contains required session info
      if (!sessionData.containsKey('session_id') ||
          !sessionData.containsKey('lecturer_id') ||
          !sessionData.containsKey('timestamp')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid attendance QR code')));
        return;
      }

      // Verify session is still active
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        sessionData['timestamp'],
      );
      final now = DateTime.now();
      if (now.difference(timestamp).inMinutes > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR code has expired (valid for 5 minutes)')),
        );
        return;
      }

      // Mark attendance using QR method
      await appProvider.markQRAttendance(
        sessionData['session_id'],
        sessionData['lecturer_id'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked successfully via QR')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking attendance: ${e.toString()}')),
      );
    }
  }

  Future<void> _requestEmergencyExit(AppProvider appProvider) async {
    final result = await context.push<bool>(routes.AppRoutes.emergencyExit);

    if (result == true) {
      // Request was successful, refresh state
      setState(() {});
    }
  }
}
