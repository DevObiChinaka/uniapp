import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniapp/screens/app_constants.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<BleStatus>? _statusSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  
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
  
  // Enhanced error handling for BLE operations
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;
  
  void _handleError(String operation, dynamic error) {
    final errorMessage = 'BLE $operation error: $error';
    print(errorMessage);
    _errorController.add(errorMessage);
  }

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
    _connectionSubscription?.cancel();
    
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    
    _deviceDiscoveredController.close();
    _bleStatusController.close();
    _scanCompleteController.close();
    _errorController.close();
  }
  
  // Check if BLE is available
  Future<bool> isBleAvailable() async {
    try {
      final status = await _ble.statusStream.first;
      return status == BleStatus.ready;
    } catch (e) {
      _handleError('availability check', e);
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
          _handleError('scan', error);
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
      _handleError('start scanning', e);
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
      _handleError('stop scanning', e);
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
          _handleError('peripheral', error);
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
          _handleError('advertising update', error);
        });
      });
      
      return true;
    } catch (e) {
      _handleError('start advertising', e);
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
      _handleError('stop advertising', e);
      return false;
    }
  }
  
  // Connect to a device
  Future<bool> connectToDevice(String deviceId) async {
    try {
      _connectionSubscription = _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 5),
      ).listen(
        (connectionState) {
          // Handle connection state changes
          print('Connection state: ${connectionState.connectionState}');
        },
        onError: (error) {
          _handleError('connection', error);
        },
      );
      return true;
    } catch (e) {
      _handleError('connect to device', e);
      return false;
    }
  }
  
  // Disconnect from a device
  Future<bool> disconnectDevice(String deviceId) async {
    try {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      return true;
    } catch (e) {
      _handleError('disconnect from device', e);
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
      _handleError('read characteristic', e);
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
      _handleError('write characteristic', e);
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
      _handleError('get cached session data', e);
      return {};
    }
  }
  
  // Cache session data
  Future<void> cacheSessionData(Map<String, dynamic> sessionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ble_session_data', jsonEncode(sessionData));
    } catch (e) {
      _handleError('cache session data', e);
    }
  }
  
  // Get connection state for a device
  Stream<ConnectionStateUpdate> getConnectionState(String deviceId) {
    return _ble.connectToDevice(id: deviceId);
  }
  
  // Check if currently scanning
  bool get isScanning => _isScanning;
  
  // Check if currently advertising  
  bool get isAdvertising => _isAdvertising;
  
  // Get discovered devices count
  int get discoveredDevicesCount => _deviceDiscoveredController.hasListener ? 1 : 0;
  
  // Check if device is connected
  Future<bool> isDeviceConnected(String deviceId) async {
    try {
      return _connectionSubscription != null;
    } catch (e) {
      _handleError('check device connection', e);
      return false;
    }
  }
  
  // Get device information
  Future<Map<String, dynamic>?> getDeviceInfo(String deviceId) async {
    try {
      // This would typically read device info characteristics
      // For now, return cached info if available
      final cachedData = await getCachedSessionData();
      return cachedData['device_$deviceId'];
    } catch (e) {
      _handleError('get device info', e);
      return null;
    }
  }
  
  // Save device information
  Future<void> saveDeviceInfo(String deviceId, Map<String, dynamic> deviceInfo) async {
    try {
      final cachedData = await getCachedSessionData();
      cachedData['device_$deviceId'] = deviceInfo;
      await cacheSessionData(cachedData);
    } catch (e) {
      _handleError('save device info', e);
    }
  }
  
  // Convenience method for attendance beacon scanning
  Future<bool> startAttendanceScanning() async {
    return await startScanning(
      serviceUuids: [AppConstants.bleServiceUuid],
      scanDuration: Duration(seconds: AppConstants.bleScanDuration),
    );
  }
  
  // Check if device is an attendance beacon
  bool isAttendanceBeacon(DiscoveredDevice device) {
    return device.serviceUuids.contains(Uuid.parse(AppConstants.bleServiceUuid)) &&
           device.rssi >= AppConstants.bleRssiThreshold;
  }
  
  // Get attendance data from beacon
  Future<Map<String, dynamic>?> getAttendanceData(DiscoveredDevice device) async {
    if (!isAttendanceBeacon(device)) {
      return null;
    }
    
    try {
      // Connect and read attendance data
      final connected = await connectToDevice(device.id);
      if (!connected) return null;
      
      final data = await readCharacteristic(
        deviceId: device.id,
        serviceUuid: AppConstants.bleServiceUuid,
        characteristicUuid: AppConstants.bleCharacteristicUuid,
      );
      
      await disconnectDevice(device.id);
      
      if (data != null) {
        return jsonDecode(data);
      }
      return null;
    } catch (e) {
      _handleError('get attendance data', e);
      return null;
    }
  }
}
