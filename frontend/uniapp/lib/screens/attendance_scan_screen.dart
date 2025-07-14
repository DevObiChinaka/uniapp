import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/screens/face_verification_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

class AttendanceScanScreen extends StatefulWidget {
  final String universityId;
  
  const AttendanceScanScreen({
    Key? key, 
    required this.universityId,
  }) : super(key: key);

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen> with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  
  bool _isProcessing = false;
  bool _isBleScanning = false;
  bool _isBluetoothOn = false;
  String _status = 'Ready to scan';
  String _scanMethod = 'qr'; // 'qr' or 'ble'
  DateTime? _lastScan;
  final _throttleDuration = const Duration(seconds: 3);
  ble.FlutterBluePlus _flutterBlue = ble.FlutterBluePlus.instance;
  List<ble.BluetoothDevice> _bleDevices = [];
  StreamSubscription<ble.ScanResult>? _bleScanSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBluetoothState();
    _initializeBle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _bleScanSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBluetoothState();
    }
  }
  
  Future<void> _checkBluetoothState() async {
    try {
      _isBluetoothOn = await _flutterBlue.isOn;
      setState(() {});
    } catch (e) {
      print('Error checking Bluetooth state: $e');
    }
  }
  
  Future<void> _initializeBle() async {
    try {
      await _checkBluetoothState();
      _flutterBlue.state.listen((state) {
        setState(() {
          _isBluetoothOn = state == ble.BluetoothState.on;
        });
      });
    } catch (e) {
      print('Error initializing BLE: $e');
    }
  }

  void _startBleScan() {
    if (!_isBluetoothOn) {
      _showMessage('Bluetooth is not enabled. Please enable Bluetooth to continue.');
      return;
    }
    
    if (_isBleScanning) return;
    
    setState(() {
      _isBleScanning = true;
      _bleDevices = [];
      _status = 'Scanning for nearby beacons...';
    });
    
    // Start scanning with timeout
    _bleScanSubscription = _flutterBlue.scan(
      timeout: Duration(seconds: AppConstants.bleScanDuration),
      withServices: [Guid(AppConstants.bleServiceUuid)]
    ).listen((scanResult) {
      // Process scan result if RSSI meets our threshold
      if (scanResult.rssi >= AppConstants.bleRssiThreshold) {
        _processBleDevice(scanResult.device);
      }
    }, onDone: () {
      setState(() {
        _isBleScanning = false;
        _status = 'BLE scan complete';
      });
      
      if (_bleDevices.isEmpty) {
        _showMessage('No attendance beacons found nearby. Please move closer to the classroom.');
      }
    }, onError: (e) {
      setState(() {
        _isBleScanning = false;
        _status = 'Scan error: $e';
      });
      _showMessage('Error scanning for beacons: $e');
    });
  }
  
  Future<void> _processBleDevice(ble.BluetoothDevice device) async {
    if (_isProcessing) return;
    if (_bleDevices.any((d) => d.id == device.id)) return;
    
    setState(() {
      _bleDevices.add(device);
    });
    
    try {
      setState(() {
        _isProcessing = true;
        _status = 'Connecting to classroom beacon...';
      });
      
      // Connect to the device
      await device.connect(autoConnect: false);
      
      // Get services
      List<ble.BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == AppConstants.bleServiceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == AppConstants.bleCharacteristicUuid) {
              // Read session data
              List<int> value = await characteristic.read();
              String sessionData = utf8.decode(value);
              
              // Process the session data
              await _processSessionData(sessionData, 'ble');
              break;
            }
          }
        }
      }
      
      // Disconnect after we're done
      await device.disconnect();
      
    } catch (e) {
      _showMessage('Error connecting to beacon: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
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
          !qrData.containsKey('timestamp')) {
        return null;
      }
      
      // Validate timestamp (TTL check)
      final timestamp = DateTime.fromMillisecondsSinceEpoch(qrData['timestamp']);
      final ttl = Duration(seconds: AppConstants.qrTtlSeconds);
      if (DateTime.now().difference(timestamp) > ttl) {
        _showMessage('QR code has expired. Please request a new one.');
        return null;
      }
      
      // Validate signature
      final payload = qrData['payload'];
      final signature = qrData['signature'];
      final secret = AppConstants.hmacSecretKey;
      
      final calculatedSignature = _generateSignature(payload, timestamp.millisecondsSinceEpoch.toString(), secret);
      
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
  
  Future<void> _processSessionData(String sessionDataStr, String method) async {
    try {
      final sessionData = jsonDecode(sessionDataStr);
      
      if (!sessionData.containsKey('session_id') || 
          !sessionData.containsKey('program')) {
        _showMessage('Invalid session data format');
        return;
      }
      
      final sessionId = sessionData['session_id'];
      final program = sessionData['program'];
      
      // Navigate to face verification for attendance
      if (!mounted) return;
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceVerificationScreen(
            verificationPurpose: 'attendance',
            sessionId: sessionId,
            universityId: widget.universityId,
            program: program,
          ),
        ),
      );
      
      if (result == true) {
        _showMessage('Attendance marked successfully!');
        Navigator.pop(context, true); // Return success to previous screen
      }
    } catch (e) {
      _showMessage('Error processing session data: $e');
    }
  }
  
  void _toggleScanMethod() {
    setState(() {
      if (_scanMethod == 'qr') {
        _scanMethod = 'ble';
        _startBleScan();
      } else {
        _scanMethod = 'qr';
        _bleScanSubscription?.cancel();
        _isBleScanning = false;
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    
    setState(() {
      _status = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan for Attendance'),
        actions: [
          IconButton(
            icon: Icon(_scanMethod == 'qr' ? Icons.bluetooth : Icons.qr_code),
            onPressed: _toggleScanMethod,
            tooltip: _scanMethod == 'qr' 
                ? 'Switch to Bluetooth scanning' 
                : 'Switch to QR code scanning',
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
          
          // Main content
          Expanded(
            child: _scanMethod == 'qr'
                ? _buildQrScanner()
                : _buildBleScanView(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQrScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
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
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scan QR code to mark attendance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBleScanView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              _isBleScanning 
                  ? 'Scanning for classroom beacons...' 
                  : 'BLE Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Make sure you are inside the classroom\nand Bluetooth is enabled',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (_isBluetoothOn)
              _isBleScanning
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: Icon(Icons.bluetooth_searching),
                      label: Text('Start Scanning'),
                      onPressed: _startBleScan,
                    )
            else
              ElevatedButton.icon(
                icon: Icon(Icons.bluetooth),
                label: Text('Enable Bluetooth'),
                onPressed: () async {
                  try {
                    await _flutterBlue.turnOn();
                    _checkBluetoothState();
                  } catch (e) {
                    _showMessage('Please enable Bluetooth manually');
                  }
                },
              ),
            SizedBox(height: 20),
            if (_bleDevices.isNotEmpty)
              Text(
                'Found ${_bleDevices.length} classroom beacons',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
