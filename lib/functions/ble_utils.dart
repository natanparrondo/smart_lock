import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

Future<void> startScanningAndConnect({
  required BuildContext context,
  required Function(BluetoothDevice) onDeviceFound,
  required Function() onScanTimeout,
}) async {
  // Start scanning for devices
  FlutterBluePlus.startScan(timeout: Duration(seconds: 15));

  FlutterBluePlus.scanResults.listen((results) {
    for (ScanResult result in results) {
      if (result.device.name == 'Lock32') {
        FlutterBluePlus.stopScan();
        onDeviceFound(result.device);
        return;
      }
    }
  });

  // Handle scan timeout
  await Future.delayed(Duration(seconds: 15));
  FlutterBluePlus.stopScan();
  onScanTimeout();
}

Future<void> writeCharacteristic(
    BluetoothCharacteristic characteristic, String data) async {
  try {
    await characteristic.write(data.codeUnits, withoutResponse: true);
  } catch (e) {
    print('Error writing characteristic: $e');
  }
}

Future<void> sendWifiData(
    BluetoothDevice device, String ssid, String password) async {
  BluetoothCharacteristic characteristic = await getCharacteristic(device);
  String data = '$ssid;$password';
  await writeCharacteristic(characteristic, data);
}

Future<BluetoothCharacteristic> getCharacteristic(
    BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();
  BluetoothService service = services.firstWhere(
    (s) => s.uuid.toString() == '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
  );
  BluetoothCharacteristic characteristic = service.characteristics.firstWhere(
    (c) => c.uuid.toString() == 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
  );
  return characteristic;
}
