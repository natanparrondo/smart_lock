// device_connection.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceConnection {
  final String serviceUUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  final String characteristicUUID = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  static final DeviceConnection _instance = DeviceConnection._internal();
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;

  factory DeviceConnection() {
    return _instance;
  }

  DeviceConnection._internal();

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> connectToDevice(BluetoothDevice device) async {
    _connectedDevice = device;
    await _connectedDevice?.connect();
    await _discoverServices();
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    List<BluetoothService> services =
        await _connectedDevice!.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == characteristicUUID) {
          _characteristic = characteristic;
        }
      }
    }
  }

  Future<void> writeCharacteristic(String value) async {
    if (_characteristic != null) {
      try {
        await _characteristic!.write(value.codeUnits, withoutResponse: false);
      } catch (e) {
        print('Error writing characteristic: $e');
      }
    } else {
      print('Characteristic is not available.');
    }
  }
}
