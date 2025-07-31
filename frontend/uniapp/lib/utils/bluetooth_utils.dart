import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

Future<bool> ensureBluetoothOn(BuildContext context) async {
  final flutterReactiveBle = FlutterReactiveBle();
  BleStatus status = flutterReactiveBle.status;
  int retries = 0;
  const int maxRetries = 3;
  const Duration retryDelay = Duration(seconds: 2);
  // Try up to maxRetries, waiting up to 5 seconds each time
  while (status != BleStatus.ready && retries < maxRetries) {
    try {
      status = await flutterReactiveBle.statusStream
          .firstWhere(
            (s) => s == BleStatus.ready,
            orElse: () => flutterReactiveBle.status,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => status);
    } catch (_) {}
    if (status == BleStatus.ready) break;
    retries++;
    if (retries < maxRetries) {
      await Future.delayed(retryDelay);
    }
  }
  if (status != BleStatus.ready) {
    final completer = Completer<bool>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Bluetooth is off. Please enable Bluetooth to start a session.',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Try Again',
          onPressed: () async {
            // On retry, do another round of status check
            BleStatus retryStatus = flutterReactiveBle.status;
            int retryCount = 0;
            while (retryStatus != BleStatus.ready && retryCount < maxRetries) {
              try {
                retryStatus = await flutterReactiveBle.statusStream
                    .firstWhere(
                      (s) => s == BleStatus.ready,
                      orElse: () => flutterReactiveBle.status,
                    )
                    .timeout(
                      const Duration(seconds: 5),
                      onTimeout: () => retryStatus,
                    );
              } catch (_) {}
              if (retryStatus == BleStatus.ready) break;
              retryCount++;
              if (retryCount < maxRetries) {
                await Future.delayed(retryDelay);
              }
            }
            if (retryStatus == BleStatus.ready) {
              completer.complete(true);
            } else {
              completer.complete(false);
            }
          },
        ),
      ),
    );
    return completer.future;
  }
  return true;
}
