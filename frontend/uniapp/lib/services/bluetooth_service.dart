import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  
  factory BluetoothService() {
    return _instance;
  }
  
  BluetoothService._internal();
  
  /// Checks if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      // First, check if device supports Bluetooth
      if (!(await FlutterBluePlus.isSupported)) {
        debugPrint('Bluetooth is not supported on this device');
        return false;
      }
      
      // Next, check if Bluetooth is turned on
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error checking Bluetooth status: $e');
      return false;
    }
  }
  
  /// Request Bluetooth permissions based on platform
  Future<bool> requestBluetoothPermissions() async {
    try {
      if (Platform.isAndroid) {
        // For Android, we need to request several permissions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
        
        // Check if all required permissions are granted
        bool allGranted = true;
        statuses.forEach((permission, status) {
          if (!status.isGranted) {
            allGranted = false;
          }
        });
        
        return allGranted;
      } else if (Platform.isIOS) {
        // iOS handles permissions through Info.plist, so just check if Bluetooth is on
        return await isBluetoothAvailable();
      }
      
      return false;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }
  
  /// Request to turn on Bluetooth
  Future<bool> requestBluetoothOn() async {
    try {
      if (Platform.isAndroid) {
        // On Android, we can request to turn on Bluetooth
        await FlutterBluePlus.turnOn();
        // Wait for the adapter state to change
        await for (final state in FlutterBluePlus.adapterState) {
          if (state == BluetoothAdapterState.on) {
            return true;
          } else if (state == BluetoothAdapterState.off) {
            return false;
          }
        }
      }
      
      // For iOS, we can't programmatically turn on Bluetooth, just check status
      return await isBluetoothAvailable();
    } catch (e) {
      debugPrint('Error turning on Bluetooth: $e');
      return false;
    }
    
    return false;
  }
}
