import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../utils/bluetooth_utils.dart';

class BleTestWidget extends StatefulWidget {
  const BleTestWidget({Key? key}) : super(key: key);

  @override
  State<BleTestWidget> createState() => _BleTestWidgetState();
}

class _BleTestWidgetState extends State<BleTestWidget> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> devices = [];
  bool scanning = false;
  String status = '';

  Future<void> startScan() async {
    setState(() {
      status = 'Checking Bluetooth...';
    });
    final btOn = await ensureBluetoothOn(context);
    if (!btOn) {
      setState(() {
        status = 'Bluetooth not enabled.';
      });
      return;
    }
    setState(() {
      status = 'Scanning...';
      scanning = true;
      devices.clear();
    });
    flutterReactiveBle
        .scanForDevices(withServices: [])
        .listen(
          (device) {
            if (!devices.any((d) => d.id == device.id)) {
              setState(() {
                devices.add(device);
              });
              debugPrint('Found device: \\${device.name} (\\${device.id})');
            }
          },
          onError: (e) {
            setState(() {
              status = 'Scan error: \\${e.toString()}';
              scanning = false;
            });
            debugPrint('Scan error: \\${e.toString()}');
          },
          onDone: () {
            setState(() {
              status = 'Scan complete.';
              scanning = false;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Test Widget')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: scanning ? null : startScan,
              child: const Text('Start BLE Scan'),
            ),
            const SizedBox(height: 16),
            Text('Status: \\${status}'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final d = devices[index];
                  return ListTile(
                    title: Text(d.name.isNotEmpty ? d.name : '(No Name)'),
                    subtitle: Text('ID: \\${d.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
