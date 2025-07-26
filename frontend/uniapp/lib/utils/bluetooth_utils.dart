import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

Future<void> openBluetoothSettings() async {
  if (Platform.isAndroid) {
    final intent = const AndroidIntent(
      action: 'android.settings.BLUETOOTH_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  } else {
    AppSettings.openAppSettings();
  }
}

Future<bool> ensureBluetoothOn(BuildContext context) async {
  final flutterReactiveBle = FlutterReactiveBle();
  // Use the current status property to avoid triggering BLE permission request/stream
  final status = flutterReactiveBle.status;
  if (status != BleStatus.ready) {
    // Prompt user to enable Bluetooth before any BLE operation
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Bluetooth Required'),
            content: const Text('Please enable Bluetooth to start a session.'),
            actions: [
              TextButton(
                onPressed: () {
                  openBluetoothSettings();
                  Navigator.of(ctx).pop(false);
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
    // After user returns, check again if Bluetooth is enabled
    final newStatus = flutterReactiveBle.status;
    if (newStatus != BleStatus.ready) {
      return false;
    }
    // Optionally, you could add a delay and re-check, or re-prompt if needed
  }
  return true;
}
