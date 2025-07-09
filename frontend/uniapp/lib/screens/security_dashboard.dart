import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_constants.dart';
import 'app_provider.dart';
import '../services/core_services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SecurityDashboard extends StatefulWidget {
  final String token;
  final String role;

  const SecurityDashboard({Key? key, required this.token, required this.role})
    : super(key: key);

  @override
  _SecurityDashboardState createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard> {
  late Timer _qrRefreshTimer;
  String _currentQrPayload = '';
  bool _isScanning = false;
  MobileScannerController? _qrController;
  int _qrTimeLeft = AppConstants.qrTtlSeconds; // Time left counter
  bool _isVerifying = false; // Verification in progress state
  Timer? _qrCountdownTimer; // Timer for visual countdown

  @override
  void initState() {
    super.initState();
    _generateQrPayload();
    _startQrRefreshTimer();
    _startQrCountdown();
  }

  @override
  void dispose() {
    _qrRefreshTimer.cancel();
    _qrCountdownTimer?.cancel();
    _qrController?.dispose();
    super.dispose();
  }

  void _generateQrPayload() {
    setState(() {
      _currentQrPayload = context.read<CoreServices>().generateQrPayload();
      _qrTimeLeft = AppConstants.qrTtlSeconds; // Reset timer on new QR
    });
  }

  void _startQrRefreshTimer() {
    _qrRefreshTimer = Timer.periodic(
      Duration(seconds: AppConstants.qrTtlSeconds),
      (timer) => _generateQrPayload(),
    );
  }

  // Added: Visual countdown timer
  void _startQrCountdown() {
    _qrCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_qrTimeLeft > 0) {
        setState(() => _qrTimeLeft--);
      } else {
        _qrTimeLeft = AppConstants.qrTtlSeconds;
      }
    });
  }

  // Added: Verification timeout handler
  Future<void> _handleExitScan(String qrData) async {
    setState(() {
      _isVerifying = true;
      _isScanning = false;
    });

    try {
      await context.read<AppProvider>().processGateExit(qrData);
    } catch (e) {
      // Show timeout error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification timed out or interrupted'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Security Dashboard'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.qr_code)),
              Tab(icon: Icon(Icons.verified_user)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildQrTab(), _buildVerificationTab(appProvider)],
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Campus Exit QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Display this QR code to students for campus exit verification',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Added visual countdown
                Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: _currentQrPayload,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    CircularProgressIndicator(
                      value: _qrTimeLeft / AppConstants.qrTtlSeconds,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Refreshing in $_qrTimeLeft seconds',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),
          Text('QR Payload:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          SelectableText(
            _currentQrPayload,
            style: TextStyle(fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTab(AppProvider appProvider) {
    return Column(
      children: [
        Expanded(child: _isScanning ? _buildScanner() : _buildScanPrompt()),
        // Show verification in progress
        if (_isVerifying) _buildVerificationProgress(),
        // Show result when available
        if (appProvider.lastExitResult != null && !_isVerifying)
          _buildVerificationResult(appProvider.lastExitResult!),
      ],
    );
  }

  // Added: Verification in-progress UI
  Widget _buildVerificationProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue, width: 2)),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Verifying student identity...',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey[400]),
          SizedBox(height: 24),
          Text(
            'Ready to Scan Student QR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Press the button below to start scanning student exit QR codes',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isScanning = true),
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Start Scanning'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
          ),
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final barcode = barcodes.first;
              if (barcode.rawValue != null) {
                _handleExitScan(barcode.rawValue!); // Use new handler
              }
            }
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isScanning = false),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Scanning for QR codes...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationResult(ExitResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.allowed ? Colors.green[50] : Colors.red[50],
        border: Border(
          top: BorderSide(
            color: result.allowed ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                result.allowed ? 'EXIT APPROVED' : 'EXIT DENIED',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.allowed ? Colors.green : Colors.red,
                  fontSize: 18,
                ),
              ),
              Icon(
                result.allowed ? Icons.check_circle : Icons.cancel,
                color: result.allowed ? Colors.green : Colors.red,
                size: 28,
              ),
            ],
          ),
          SizedBox(height: 16),
          if (result.studentName != null) ...[
            Text(
              'Student: ${result.studentName}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
          ],
          Text(result.message),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16),
              SizedBox(width: 4),
              Text(Utils.formatDateTime(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }
}
