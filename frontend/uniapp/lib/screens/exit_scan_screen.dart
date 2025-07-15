import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/face_verification_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ExitScanScreen extends StatefulWidget {
  final String universityId;
  final bool hasApprovedLeave;

  const ExitScanScreen({
    Key? key,
    required this.universityId,
    this.hasApprovedLeave = false,
  }) : super(key: key);

  @override
  State<ExitScanScreen> createState() => _ExitScanScreenState();
}

class _ExitScanScreenState extends State<ExitScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _isProcessing = false;
  String _status = 'Ready to scan security QR code';
  DateTime? _lastScan;
  final _throttleDuration = const Duration(seconds: 3);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processQrCode(String data) async {
    // Check for throttling
    final now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!) < _throttleDuration) {
      // Throttle rapid scans
      return;
    }
    _lastScan = now;

    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _status = 'Processing exit QR code...';
      });

      // Validate QR format and signature
      final qrData = _validateQrCode(data);
      if (qrData == null) {
        _showMessage('Invalid security QR code');
        return;
      }

      // Process the exit data from QR
      await _processExitRequest(qrData['payload']);
    } catch (e) {
      _showMessage('Error processing QR code: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic>? _validateQrCode(String data) {
    try {
      // Parse QR data
      final qrData = jsonDecode(data);

      // Check if required fields exist
      if (!qrData.containsKey('payload') ||
          !qrData.containsKey('signature') ||
          !qrData.containsKey('timestamp') ||
          !qrData.containsKey('type')) {
        return null;
      }

      // Check if this is an exit QR code
      if (qrData['type'] != 'exit') {
        _showMessage('Invalid QR code type. This is not an exit QR code.');
        return null;
      }

      // Validate timestamp (TTL check)
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        qrData['timestamp'],
      );
      final ttl = Duration(seconds: AppConstants.qrTtlSeconds);
      if (DateTime.now().difference(timestamp) > ttl) {
        _showMessage(
          'QR code has expired. Please request a new one from security personnel.',
        );
        return null;
      }

      // Validate signature
      final payload = qrData['payload'];
      final signature = qrData['signature'];
      final secret = AppConstants.hmacSecretKey;

      final calculatedSignature = _generateSignature(
        payload,
        timestamp.millisecondsSinceEpoch.toString(),
        secret,
      );

      if (calculatedSignature != signature) {
        return null;
      }

      return qrData;
    } catch (e) {
      print('QR validation error: $e');
      return null;
    }
  }

  String _generateSignature(String payload, String timestamp, String secret) {
    final dataToSign = payload + timestamp;
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(dataToSign));
    return digest.toString();
  }

  Future<void> _processExitRequest(String exitDataStr) async {
    try {
      final exitData = jsonDecode(exitDataStr);

      if (!exitData.containsKey('gate_id')) {
        _showMessage('Invalid exit data format');
        return;
      }

      final gateId = exitData['gate_id'];

      // Navigate to face verification for exit
      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) => FaceVerificationScreen(
                title: 'Exit Verification',
                subtitle: 'Verify your identity to exit campus',
                onVerificationComplete: (
                  bool isVerified,
                  String? faceId,
                ) async {
                  if (isVerified && faceId != null) {
                    await _processExit(gateId, faceId);
                    return true;
                  }
                  return false;
                },
              ),
        ),
      );

      if (result == true) {
        _showSuccessMessage('Exit authorized successfully!');
        Navigator.pop(context, true);
      } else {
        _showMessage('Exit verification failed. Please try again.');
      }
    } catch (e) {
      _showMessage('Error processing exit data: $e');
    }
  }

  Future<void> _processExit(String gateId, String faceId) async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);

      // Create exit request data
      final exitQrData =
          'EXIT:${widget.universityId}:$gateId:${DateTime.now().millisecondsSinceEpoch}';

      // Process gate exit using AppProvider
      await provider.processGateExit(exitQrData);

      // Check the result
      final exitResult = provider.lastExitResult;

      if (exitResult != null && exitResult.allowed) {
        _showSuccessMessage('Exit approved: ${exitResult.message}');
      } else {
        throw Exception(exitResult?.message ?? 'Exit denied');
      }
    } catch (e) {
      throw Exception('Failed to process exit: $e');
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

  void _showEmergencyExitDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Emergency Exit'),
              ],
            ),
            content: Text(
              'Emergency exits require additional verification. Continue to proceed with emergency exit process.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Continue with emergency exit verification
                  _showMessage(
                    'Please scan security QR code for emergency exit authorization',
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Continue'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exit Campus'),
        actions: [
          if (!widget.hasApprovedLeave)
            IconButton(
              icon: Icon(Icons.warning_amber),
              tooltip: 'Emergency Exit',
              onPressed: _showEmergencyExitDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _isProcessing ? Icons.sync : Icons.info_outline,
                  color: Colors.blue,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),

          // Leave status bar
          if (widget.hasApprovedLeave)
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have an approved leave request',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      final code = barcodes.first.rawValue!;
                      _processQrCode(code);
                    }
                  },
                ),
                // Overlay with scanning guide
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              widget.hasApprovedLeave
                                  ? Colors.green
                                  : Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color:
                                widget.hasApprovedLeave
                                    ? Colors.green
                                    : Colors.white,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Scan Security QR Code\nto Exit Campus',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  widget.hasApprovedLeave
                                      ? Colors.green
                                      : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Instructions
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1.'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scan the QR code displayed by security personnel',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2.'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verify your identity with face verification',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('3.'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.hasApprovedLeave
                            ? 'Exit will be approved based on your leave request'
                            : 'Submit emergency exit request if needed',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // No leave request notice
          if (!widget.hasApprovedLeave)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No approved leave request found. To exit campus regularly, submit a leave request and get approval.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Bottom button for emergency
      bottomNavigationBar:
          !widget.hasApprovedLeave
              ? BottomAppBar(
                height: 60,
                padding: EdgeInsets.zero,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.warning),
                  label: Text('Request Emergency Exit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/emergency_exit');
                  },
                ),
              )
              : null,
    );
  }
}
