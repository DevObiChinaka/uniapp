import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/services/ble_service.dart';
import 'package:uniapp/utils/bluetooth_utils.dart';
import 'package:uniapp/utils/permission_utils.dart';

class LecturerQrGenerationScreen extends StatefulWidget {
  final String sessionId;
  final String program;

  const LecturerQrGenerationScreen({
    super.key,
    required this.sessionId,
    required this.program,
  });

  @override
  State<LecturerQrGenerationScreen> createState() =>
      _LecturerQrGenerationScreenState();
}

class _LecturerQrGenerationScreenState
    extends State<LecturerQrGenerationScreen> {
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
    debugPrint('[BLE] Initializing BLE service...');
    // Prompt for Bluetooth ON
    final btOk = await ensureBluetoothOn(context);
    debugPrint('[BLE] Bluetooth enabled: $btOk');
    if (!btOk) {
      setState(() {
        _isBleEnabled = false;
      });
      return;
    }
    // Check permissions
    final permsOk = await ensureBlePermissions(context);
    debugPrint('[BLE] Permissions granted: $permsOk');
    if (!permsOk) {
      setState(() {
        _isBleEnabled = false;
      });
      return;
    }
    _bleService = BleService();
    await _bleService!.initialize();
    final isAvailable = await _bleService!.isBleAvailable();
    debugPrint('[BLE] BLE available: $isAvailable');
    setState(() {
      _isBleEnabled = isAvailable;
    });
    _bleService!.onStatusChange.listen((status) {
      debugPrint('[BLE] Status changed: $status');
      setState(() {
        _isBleEnabled = (status == BleStatus.ready);
        if (!_isBleEnabled && _isBleAdvertising) {
          debugPrint('[BLE] BLE disabled while advertising, stopping...');
          _stopBleAdvertising();
        }
      });
    });
    if (isAvailable) {
      _startBleAdvertising();
    } else {
      debugPrint('[BLE] BLE not available, cannot advertise.');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft = (_secondsLeft - 1);
        if (_secondsLeft <= 0) {
          _secondsLeft = AppConstants.qrTtlSeconds;
        }
      });
    });
  }

  void _generateQrCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = _createPayload();
    final signature = _generateSignature(payload, timestamp.toString());
    final qrData = {
      'payload': payload,
      'timestamp': timestamp,
      'signature': signature,
    };
    setState(() {
      _qrData = jsonEncode(qrData);
      _secondsLeft = AppConstants.qrTtlSeconds;
    });
    if (_isBleAdvertising && _bleService != null) {
      _updateBleAdvertisingData(payload);
    }
  }

  Future<void> _updateBleAdvertisingData(String payload) async {
    try {
      await _bleService!.stopPeripheralAdvertising();
      await _bleService!.startPeripheralAdvertising(
        serviceUuid: AppConstants.bleServiceUuid,
        data: payload,
      );
    } catch (e) {
      print('Error updating BLE advertising data: $e');
    }
  }

  Future<void> _toggleBleAdvertising(bool enable) async {
    if (enable && !_isBleAdvertising) {
      await _startBleAdvertising();
    } else if (!enable && _isBleAdvertising) {
      await _stopBleAdvertising();
    }
  }

  Future<void> _startBleAdvertising() async {
    if (_bleService == null) {
      debugPrint('[BLE] _bleService is null, cannot advertise.');
      return;
    }
    try {
      final blePayload = _createPayload();
      debugPrint(
        '[BLE] Attempting to start advertising with payload: $blePayload',
      );
      final success = await _bleService!.startPeripheralAdvertising(
        serviceUuid: AppConstants.bleServiceUuid,
        data: blePayload,
      );
      debugPrint('[BLE] Advertising result: $success');
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
        debugPrint('[BLE] Failed to activate Bluetooth proximity attendance.');
      }
    } catch (e) {
      debugPrint('[BLE] Exception during advertising: $e');
      setState(() {
        _isBleAdvertising = false;
      });
    }
  }

  Future<void> _stopBleAdvertising() async {
    if (_bleService == null) return;
    try {
      final success = await _bleService!.stopPeripheralAdvertising();
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
            // ...existing code for UI (copy from your current QR screen)...
          ],
        ),
      ),
    );
  }
}
