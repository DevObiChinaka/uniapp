// Example integration of BleService with the attendance system
// This demonstrates how the BLE service could be used for attendance scanning

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../services/ble_service.dart';
import '../screens/app_constants.dart';

class BleAttendanceExample {
  final BleService _bleService = BleService();

  Future<void> initialize() async {
    await _bleService.initialize();

    // Listen for device discoveries
    _bleService.onDeviceDiscovered.listen((device) {
      if (_bleService.isAttendanceBeacon(device)) {
        _handleAttendanceBeacon(device);
      }
    });

    // Listen for errors
    _bleService.onError.listen((error) {
      debugPrint('BLE Error: $error');
    });
  }

  Future<void> startAttendanceScanning() async {
    final bleAvailable = await _bleService.isBleAvailable();
    if (!bleAvailable) {
      debugPrint('BLE not available');
      return;
    }

    final started = await _bleService.startAttendanceScanning();
    if (started) {
      debugPrint('Attendance scanning started');
    } else {
      debugPrint('Failed to start attendance scanning');
    }
  }

  Future<void> _handleAttendanceBeacon(DiscoveredDevice device) async {
    debugPrint('Found attendance beacon: ${device.name} (${device.rssi} dBm)');

    final attendanceData = await _bleService.getAttendanceData(device);
    if (attendanceData != null) {
      debugPrint('Attendance data: $attendanceData');
      // Process attendance data...
    }
  }

  Future<void> dispose() async {
    await _bleService.dispose();
  }
}
