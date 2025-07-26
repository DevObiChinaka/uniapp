import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

Future<bool> ensureBlePermissions(BuildContext context) async {
  final permissions = [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.locationWhenInUse,
  ];
  bool allGranted = true;
  for (final perm in permissions) {
    final status = await perm.status;
    if (!status.isGranted) {
      final result = await perm.request();
      if (!result.isGranted) {
        allGranted = false;
      }
    }
  }
  if (!allGranted) {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'Bluetooth and Location permissions are required for proximity attendance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
  return allGranted;
}
