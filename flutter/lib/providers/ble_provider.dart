import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvider with ChangeNotifier {
  static const String lirikServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lirikCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _lirikCharacteristic;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _lirikCharacteristic != null;

  BleProvider() {
    FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });
  }

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connect(BluetoothDevice btDevice, String pin) async {
    try {
      await btDevice.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      _connectedDevice = btDevice;

      List<BluetoothService> services = await btDevice.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            lirikServiceUuid.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                lirikCharacteristicUuid.toLowerCase()) {
              _lirikCharacteristic = characteristic;
              break;
            }
          }
        }
      }
      notifyListeners();
      return _lirikCharacteristic != null;
    } catch (e) {
      debugPrint('Connect error: $e');
      return false;
    }
  }

  Future<void> writeBatchJson(String jsonPayload) async {
    if (_lirikCharacteristic == null) return;

    String fullMsg = "$jsonPayload[EOF]";
    List<int> bytes = utf8.encode(fullMsg);

    await _splitWrite(_lirikCharacteristic!, bytes);
  }

  Future<void> sendReset() async {
    if (_lirikCharacteristic == null) return;
    String cmd = "${jsonEncode({"c": "reset"})}[EOF]";
    List<int> bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes);
  }

  Future<void> _splitWrite(BluetoothCharacteristic c, List<int> value) async {
    int chunk = min(c.device.mtuNow - 3, 500);

    for (int i = 0; i < value.length; i += chunk) {
      List<int> subvalue = value.sublist(i, min(i + chunk, value.length));
      await c.write(subvalue, withoutResponse: false);
    }
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _lirikCharacteristic = null;
    notifyListeners();
  }
}
