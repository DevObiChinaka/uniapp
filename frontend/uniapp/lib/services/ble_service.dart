import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniapp/screens/app_constants.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<BleStatus>? _statusSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  
  bool _isAdvertising = false;
  bool _isScanning = false;
  
  // For advertising
  QualifiedCharacteristic? _characteristic;
  Stream<BleStatus>? _statusStream;
  final List<StreamSubscription<void>> _subscriptions = [];
  
  // Events
  final _deviceDiscoveredController = StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get onDeviceDiscovered => _deviceDiscoveredController.stream;
  
  final _bleStatusController = StreamController<BleStatus>.broadcast();
  Stream<BleStatus> get onStatusChange => _bleStatusController.stream;
  
  final _scanCompleteController = StreamController<void>.broadcast();
  Stream<void> get onScanComplete => _scanCompleteController.stream;
  
  // Initialize
  Future<void> initialize() async {
    _statusStream = _ble.statusStream;
    _statusSubscription = _statusStream?.listen((status) {
      _bleStatusController.add(status);
    });
  }
  
  // Dispose
  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
    
    _statusSubscription?.cancel();
    _scanSubscription?.cancel();
    
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    
    _deviceDiscoveredController.close();
    _bleStatusController.close();
    _scanCompleteController.close();
  }
  
  // Check if BLE is available
  Future<bool> isBleAvailable() async {
    try {
      final status = await _ble.statusStream.first;
      return status == BleStatus.ready;
    } catch (e) {
      print('Error checking BLE status: $e');
      return false;
    }
  }
  
  // Start scanning for devices
  Future<bool> startScanning({
    required List<String> serviceUuids,
    Duration? scanDuration,
  }) async {
    if (_isScanning) {
      return true;
    }
    
    try {
      _isScanning = true;
      
      _scanSubscription = _ble.scanForDevices(
        withServices: serviceUuids.map((uuid) => Uuid.parse(uuid)).toList(),
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          // Filter by RSSI threshold
          if (device.rssi >= AppConstants.bleRssiThreshold) {
            _deviceDiscoveredController.add(device);
          }
        },
        onError: (error) {
          print('BLE scan error: $error');
          _isScanning = false;
        },
      );
      
      // Set scan timeout
      if (scanDuration != null) {
        Future.delayed(scanDuration, () {
          stopScanning().then((_) {
            _scanCompleteController.add(null);
          });
        });
      }
      
      return true;
    } catch (e) {
      print('Error starting BLE scan: $e');
      _isScanning = false;
      return false;
    }
  }
  
  // Stop scanning
  Future<bool> stopScanning() async {
    if (!_isScanning) {
      return true;
    }
    
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      return true;
    } catch (e) {
      print('Error stopping BLE scan: $e');
      return false;
    }
  }
  
  // Start advertising (peripheral mode)
  Future<bool> startAdvertising({
    required String serviceUuid,
    required String characteristicUuid,
    required String data,
  }) async {
    if (_isAdvertising) {
      return true;
    }
    
    try {
      final service = Uuid.parse(serviceUuid);
      final characteristic = Uuid.parse(characteristicUuid);
      
      // Create characteristic
      _characteristic = QualifiedCharacteristic(
        serviceId: service,
        characteristicId: characteristic,
        deviceId: '00:00:00:00:00:00', // Not used for advertising
      );
      
      // Start peripheral service
      _subscriptions.add(
        _ble.subscribeToCharacteristic(_characteristic!).listen((data) {
          // Handle read requests
        }, onError: (error) {
          print('BLE peripheral error: $error');
        }),
      );
      
      // Write data to characteristic
      final payload = utf8.encode(data);
      await _ble.writeCharacteristicWithResponse(
        _characteristic!,
        value: payload,
      );
      
      _isAdvertising = true;
      
      // Update advertising at regular intervals
      Timer.periodic(Duration(milliseconds: AppConstants.bleAdvertiseInterval), (timer) {
        if (!_isAdvertising) {
          timer.cancel();
          return;
        }
        
        _ble.writeCharacteristicWithResponse(
          _characteristic!,
          value: payload,
        ).catchError((error) {
          print('BLE advertising update error: $error');
        });
      });
      
      return true;
    } catch (e) {
      print('Error starting BLE advertising: $e');
      return false;
    }
  }
  
  // Stop advertising
  Future<bool> stopAdvertising() async {
    if (!_isAdvertising) {
      return true;
    }
    
    try {
      for (var subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      
      _isAdvertising = false;
      _characteristic = null;
      
      return true;
    } catch (e) {
      print('Error stopping BLE advertising: $e');
      return false;
    }
  }
  
  // Connect to a device
  Future<bool> connectToDevice(String deviceId) async {
    try {
      await _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 5),
      ).first;
      return true;
    } catch (e) {
      print('Error connecting to BLE device: $e');
      return false;
    }
  }
  
  // Disconnect from a device
  Future<bool> disconnectDevice(String deviceId) async {
    try {
      await _ble.disconnectDevice(id: deviceId);
      return true;
    } catch (e) {
      print('Error disconnecting from BLE device: $e');
      return false;
    }
  }
  
  // Read characteristic from a device
  Future<String?> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuid),
        deviceId: deviceId,
      );
      
      final response = await _ble.readCharacteristic(characteristic);
      return utf8.decode(response);
    } catch (e) {
      print('Error reading BLE characteristic: $e');
      return null;
    }
  }
  
  // Write characteristic to a device
  Future<bool> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String data,
  }) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuid),
        deviceId: deviceId,
      );
      
      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: utf8.encode(data),
      );
      
      return true;
    } catch (e) {
      print('Error writing BLE characteristic: $e');
      return false;
    }
  }
  
  // Get cached session data
  Future<Map<String, dynamic>> getCachedSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionDataJson = prefs.getString('ble_session_data');
      
      if (sessionDataJson == null) {
        return {};
      }
      
      return jsonDecode(sessionDataJson);
    } catch (e) {
      print('Error getting cached session data: $e');
      return {};
    }
  }
  
  // Cache session data
  Future<void> cacheSessionData(Map<String, dynamic> sessionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ble_session_data', jsonEncode(sessionData));
    } catch (e) {
      print('Error caching session data: $e');
    }
  }
}
