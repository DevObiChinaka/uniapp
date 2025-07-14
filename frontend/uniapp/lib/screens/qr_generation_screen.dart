import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/services/ble_service.dart';

class QrGenerationScreen extends StatefulWidget {
  final String sessionId;
  final String program;
  
  const QrGenerationScreen({
    Key? key, 
    required this.sessionId,
    required this.program,
  }) : super(key: key);

  @override
  State<QrGenerationScreen> createState() => _QrGenerationScreenState();
}

class _QrGenerationScreenState extends State<QrGenerationScreen> {
  String _qrData = '';
  int _secondsLeft = AppConstants.qrTtlSeconds;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  
  // BLE state variables
  bool _isBleEnabled = false;
  bool _isBleAdvertising = false;
  BleService? _bleService;
  
  @override
  void initState() {
    super.initState();
    _generateQrCode();
    _startRefreshTimer();
    _startCountdownTimer();
    _initializeBleService();
  }
  
  Future<void> _initializeBleService() async {
    _bleService = BleService();
    await _bleService!.initialize();
    
    // Check initial availability
    final isAvailable = await _bleService!.isBleAvailable();
    setState(() {
      _isBleEnabled = isAvailable;
    });
    
    // Listen to BLE status changes
    _bleService!.onStatusChange.listen((status) {
      setState(() {
        // Update BLE status based on the status event
        _isBleEnabled = (status == BleStatus.ready);
        
        // If BLE is disabled but we're advertising, stop advertising
        if (!_isBleEnabled && _isBleAdvertising) {
          _stopBleAdvertising();
        }
      });
    });
    _bleService!.onStatusChange.listen((status) {
      setState(() {
        // Update BLE status based on the status event
        _isBleEnabled = (status == BleStatus.ready);
        
        // If BLE is disabled but we're advertising, stop advertising
        if (!_isBleEnabled && _isBleAdvertising) {
          _stopBleAdvertising();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    // Stop BLE advertising if active
    if (_isBleAdvertising) {
      _stopBleAdvertising();
    }
    _bleService?.dispose();
    super.dispose();
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(
      Duration(seconds: AppConstants.qrTtlSeconds),
      (_) => _generateQrCode(),
    );
  }
  
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        setState(() {
          _secondsLeft = (_secondsLeft - 1);
          if (_secondsLeft <= 0) {
            _secondsLeft = AppConstants.qrTtlSeconds;
          }
        });
      },
    );
  }
  
  void _generateQrCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = _createPayload();
    
    // Create signature with HMAC
    final signature = _generateSignature(payload, timestamp.toString());
    
    // Create final QR data
    final qrData = {
      'payload': payload,
      'timestamp': timestamp,
      'signature': signature,
    };
    
    setState(() {
      _qrData = jsonEncode(qrData);
      _secondsLeft = AppConstants.qrTtlSeconds;
    });
    
    // Update BLE advertising data if active
    if (_isBleAdvertising && _bleService != null) {
      _updateBleAdvertisingData(payload);
    }
  }
  
  Future<void> _updateBleAdvertisingData(String payload) async {
    try {
      // Stop and restart advertising with new payload
      await _bleService!.stopAdvertising();
      await _bleService!.startAdvertising(
        serviceUuid: AppConstants.bleServiceUuid,
        characteristicUuid: AppConstants.bleCharacteristicUuid,
        data: payload,
      );
    } catch (e) {
      print('Error updating BLE advertising data: $e');
    }
  }
  
  // BLE methods
  Future<void> _toggleBleAdvertising(bool enable) async {
    if (enable && !_isBleAdvertising) {
      await _startBleAdvertising();
    } else if (!enable && _isBleAdvertising) {
      await _stopBleAdvertising();
    }
  }
  
  Future<void> _startBleAdvertising() async {
    if (_bleService == null) return;
    
    try {
      // Create the BLE payload
      final blePayload = _createPayload();
      
      final success = await _bleService!.startAdvertising(
        serviceUuid: AppConstants.bleServiceUuid,
        characteristicUuid: AppConstants.bleCharacteristicUuid,
        data: blePayload,
      );
      
      setState(() {
        _isBleAdvertising = success;
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth proximity attendance is now active'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to activate Bluetooth proximity attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error starting BLE advertising: $e');
      setState(() {
        _isBleAdvertising = false;
      });
    }
  }
  
  Future<void> _stopBleAdvertising() async {
    if (_bleService == null) return;
    
    try {
      final success = await _bleService!.stopAdvertising();
      setState(() {
        _isBleAdvertising = !success;
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth proximity attendance is now inactive'),
          ),
        );
      }
    } catch (e) {
      print('Error stopping BLE advertising: $e');
    }
  }
  
  String _createPayload() {
    // Create the session payload
    final payload = jsonEncode({
      'session_id': widget.sessionId,
      'program': widget.program,
      'timestamp': DateTime.now().toIso8601String(),
      'ble_enabled': _isBleAdvertising,
      'service_uuid': AppConstants.bleServiceUuid,
      'characteristic_uuid': AppConstants.bleCharacteristicUuid,
    });
    
    return payload;
  }
  
  String _generateSignature(String payload, String timestamp) {
    final dataToSign = payload + timestamp;
    final hmac = Hmac(sha256, utf8.encode(AppConstants.hmacSecretKey));
    final digest = hmac.convert(utf8.encode(dataToSign));
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance QR Code'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _generateQrCode,
            tooltip: 'Generate New QR Code',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Session info card
            Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Active Session',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Program: ${widget.program}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Session ID: ${widget.sessionId}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // QR Code
            _qrData.isNotEmpty 
                ? Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _qrData,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                        ),
                        SizedBox(height: 16),
                        // Countdown indicator
                        _buildCountdownIndicator(),
                      ],
                    ),
                  )
                : CircularProgressIndicator(),
            
            SizedBox(height: 32),
            
            // Instructions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Instructions', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Display this QR code to students\n'
                    '2. Ask them to scan with their app\n'
                    '3. QR code refreshes automatically for security\n'
                    '4. Tap refresh icon to generate a new code\n'
                    '5. Enable Bluetooth for proximity-based attendance',
                    style: TextStyle(height: 1.3),
                  ),
                ],
              ),
            ),
            
            // BLE attendance stats if active
            if (_isBleAdvertising)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.devices_other, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Bluetooth Attendance Stats',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Students in range will appear here'),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Students with the app open will automatically connect when in range',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            
            Spacer(),
            
            // Alternative method button (BLE)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isBleAdvertising ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBleAdvertising ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bluetooth, 
                        color: _isBleAdvertising ? Colors.green : Colors.grey,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Bluetooth Proximity Attendance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isBleAdvertising ? Colors.green.shade800 : Colors.grey.shade800,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isBleAdvertising ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isBleAdvertising ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isBleAdvertising
                        ? 'Broadcasting attendance data to nearby devices'
                        : 'Enable to allow students to mark attendance via Bluetooth',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(_isBleAdvertising ? Icons.stop : Icons.play_arrow),
                    label: Text(_isBleAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBleAdvertising ? Colors.red : Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size(double.infinity, 36),
                    ),
                    onPressed: _isBleEnabled ? () => _showBleDialog() : null,
                  ),
                  if (!_isBleEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Bluetooth is disabled on your device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCountdownIndicator() {
    final progress = _secondsLeft / AppConstants.qrTtlSeconds;
    
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress > 0.5 
                ? Colors.green 
                : (progress > 0.25 ? Colors.orange : Colors.red)
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer,
              size: 16,
              color: progress > 0.25 ? Colors.black54 : Colors.red,
            ),
            SizedBox(width: 4),
            Text(
              'Refreshing in $_secondsLeft seconds',
              style: TextStyle(
                color: progress > 0.25 ? Colors.black54 : Colors.red,
                fontWeight: progress > 0.25 ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _showBleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 8),
            Text('Bluetooth Attendance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth attendance allows students within range of your device to mark attendance automatically without scanning the QR code.',
            ),
            SizedBox(height: 16),
            if (!_isBleEnabled)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bluetooth needs to be enabled on your device',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _isBleAdvertising ? Icons.check_circle : Icons.radio_button_unchecked, 
                  color: _isBleAdvertising ? Colors.green : Colors.grey, 
                  size: 16
                ),
                SizedBox(width: 8),
                Text(
                  _isBleAdvertising ? 'Broadcasting active' : 'Broadcasting inactive',
                  style: TextStyle(
                    color: _isBleAdvertising ? Colors.green.shade800 : Colors.grey.shade700,
                    fontWeight: _isBleAdvertising ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.wifi_tethering, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Text('Range: ~10 meters'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Session data is broadcast using Bluetooth Low Energy. Students with the app installed can mark attendance automatically when in range.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text(_isBleAdvertising ? 'Disable' : 'Enable'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBleAdvertising ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: _isBleEnabled ? () {
              _toggleBleAdvertising(!_isBleAdvertising);
              Navigator.pop(context);
            } : null,
          ),
        ],
      ),
    );
  }
}
