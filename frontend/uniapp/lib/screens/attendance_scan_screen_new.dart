import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/face_verification_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AttendanceScanScreen extends StatefulWidget {
  final String universityId;

  const AttendanceScanScreen({super.key, required this.universityId});

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _isProcessing = false;
  String _status = 'Ready to scan';
  DateTime? _lastScan;
  final _throttleDuration = const Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    } else if (state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  Future<void> _processQrCode(String data) async {
    // Check for throttling
    final now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!) < _throttleDuration) {
      return;
    }
    _lastScan = now;

    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _status = 'Processing QR code...';
      });

      // Validate QR format and signature
      final qrData = _validateQrCode(data);
      if (qrData == null) {
        _showMessage('Invalid QR code format');
        return;
      }

      // Process the session data from QR
      await _processSessionData(qrData['payload'], 'qr');
    } catch (e) {
      _showMessage('Error processing QR code: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _status = 'Ready to scan';
      });
    }
  }

  Map<String, dynamic>? _validateQrCode(String data) {
    try {
      final Map<String, dynamic> qrData = jsonDecode(data);

      // Check required fields
      if (!qrData.containsKey('session_id') ||
          !qrData.containsKey('lecturer_id') ||
          !qrData.containsKey('timestamp') ||
          !qrData.containsKey('program')) {
        return null;
      }

      // Check timestamp validity (within 5 minutes)
      final timestamp = qrData['timestamp'] as int;
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(qrTime).inMinutes > 5) {
        _showMessage('QR code has expired. Please ask lecturer for a new one.');
        return null;
      }

      return {'payload': data};
    } catch (e) {
      return null;
    }
  }

  Future<void> _processSessionData(String sessionData, String method) async {
    try {
      final Map<String, dynamic> data = jsonDecode(sessionData);
      final sessionId = data['session_id'] as String;
      final program = data['program'] as String;

      setState(() {
        _status = 'Verifying attendance...';
      });

      // Navigate to face verification
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) => FaceVerificationScreen(
                onVerificationComplete: (
                  bool isVerified,
                  String? faceId,
                ) async {
                  if (isVerified && faceId != null) {
                    await _markAttendance(sessionId, program, method);
                    return true;
                  }
                  return false;
                },
              ),
        ),
      );

      if (result == true) {
        _showSuccessMessage('Attendance marked successfully!');
        Navigator.pop(context);
      } else {
        _showMessage('Face verification failed. Please try again.');
      }
    } catch (e) {
      _showMessage('Error processing session data: $e');
    }
  }

  Future<void> _markAttendance(
    String sessionId,
    String program,
    String method,
  ) async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);

      final success = await provider.coreServices.markAttendance(
        userId: widget.universityId,
        sessionId: sessionId,
        faceVerified: true,
      );

      if (!success) {
        throw Exception('Failed to mark attendance on server');
      }
    } catch (e) {
      throw Exception('Failed to mark attendance: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan for Attendance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Scan QR Code for Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _status,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (BarcodeCapture capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _processQrCode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            _status,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                // QR code frame overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner frames
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.green, width: 4),
                                left: BorderSide(color: Colors.green, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.green, width: 4),
                                right: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                                left: BorderSide(color: Colors.green, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                                right: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _isProcessing
                          ? null
                          : () {
                            _scannerController.toggleTorch();
                          },
                  icon: Icon(Icons.flash_on),
                  label: Text('Toggle Flash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Position the QR code within the frame to scan',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
