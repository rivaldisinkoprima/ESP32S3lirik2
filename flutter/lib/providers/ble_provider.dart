// BLE Provider
//
// Fungsi:
// - Manage Bluetooth BLE connection ke ESP32
// - Scan device, connect/disconnect
// - Write data: Kirim JSON payload dengan chunking 512 bytes
// - Send reset: Kirim command factory reset
// - Send check: Kirim command untuk cek isi LittleFS ESP32
//
// UUIDs:
// - Service: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
// - Characteristic: beb5483e-36e1-4688-b7f5-ea07361b26a8

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Model data hasil CHECK dari ESP32
class DeretCheckResult {
  final int slot;
  final String name;
  final List<String> words;

  DeretCheckResult({
    required this.slot,
    required this.name,
    required this.words,
  });

  factory DeretCheckResult.fromJson(Map<String, dynamic> json) {
    return DeretCheckResult(
      slot: json['d'] as int,
      name: json['name'] as String? ?? 'Deret ${json['d']}',
      words: List<String>.from(
        (json['w'] as List? ?? []).map((w) => w.toString()),
      ),
    );
  }
}

class BleProvider with ChangeNotifier {
  static const String lirikServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lirikCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _lirikCharacteristic;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String _lastStatus = "";
  StreamSubscription? _statusSub;
  StreamSubscription? _connectionSub;

  // --- State untuk fitur CHECK ---
  bool _isChecking = false;
  List<DeretCheckResult>? _checkResults; // null = belum pernah cek, [] = sudah cek & kosong
  String _checkBuffer = ""; // Buffer reassembly untuk respons chunked dari ESP32

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _lirikCharacteristic != null;
  String get lastStatus => _lastStatus;
  bool get isChecking => _isChecking;
  List<DeretCheckResult>? get checkResults => _checkResults;

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

      if (_lirikCharacteristic != null) {
        // Pantau status koneksi perangkat (Lost, Disconnected, dll)
        _connectionSub = btDevice.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            debugPrint('[BLE-STATE] Device DISCONNECTED');
            _cleanupLocal();
          }
        });

        // Aktifkan NOTIFY & listen semua incoming messages
        await _lirikCharacteristic!.setNotifyValue(true);
        _statusSub = _lirikCharacteristic!.onValueReceived.listen((value) {
          _handleIncomingNotify(utf8.decode(value));
        });
      }

      notifyListeners();
      return _lirikCharacteristic != null;
    } catch (e) {
      debugPrint('Connect error: $e');
      return false;
    }
  }

  /// Router untuk semua pesan masuk dari ESP32 via NOTIFY
  void _handleIncomingNotify(String data) {
    debugPrint('[BLE-NOTIFY-RX] Received: ${data.length} bytes');

    if (_isChecking) {
      // Sedang dalam mode CHECK: kumpulkan ke buffer dulu
      _checkBuffer += data;
      debugPrint('[BLE-CHECK] Buffer size: ${_checkBuffer.length} bytes');

      // Cek apakah sudah ada delimiter akhir data
      final eofIndex = _checkBuffer.indexOf('[DATA_EOF]');
      if (eofIndex != -1) {
        final payload = _checkBuffer.substring(0, eofIndex);
        _checkBuffer = "";
        _isChecking = false;
        debugPrint('[BLE-CHECK] Complete payload received (${payload.length} bytes), parsing...');
        _parseCheckPayload(payload);
      }
    } else {
      // Mode normal: status feedback singkat (OK:10/10, ERR:...)
      _lastStatus = data;
      debugPrint('[BLE-FEEDBACK] Status dari ESP32: $_lastStatus');
      notifyListeners();
    }
  }

  /// Parse JSON hasil CHECK dari ESP32
  void _parseCheckPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        debugPrint('[BLE-CHECK] ERROR: Expected JSON array');
        _checkResults = [];
        notifyListeners();
        return;
      }
      _checkResults = decoded
          .map((item) => DeretCheckResult.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint('[BLE-CHECK] Parsed ${_checkResults?.length} derets');
    } catch (e) {
      debugPrint('[BLE-CHECK] JSON parse error: $e');
      _checkResults = [];
    }
    notifyListeners();
  }

  Future<void> writeBatchJson(String jsonPayload) async {
    if (_lirikCharacteristic == null) return;

    // PENTING: Kosongkan status sebelumnya agar pengkondisian (if (ble.lastStatus == 'OK:')) 
    // pada layar sinkronisasi tidak langsung bernilai true dari historis sesi sebelumnya.
    _lastStatus = "";

    String fullMsg = "$jsonPayload[EOF]";
    List<int> bytes = utf8.encode(fullMsg);

    await _splitWrite(_lirikCharacteristic!, bytes);
  }

  Future<void> sendReset() async {
    if (_lirikCharacteristic == null) return;
    
    // Bersihkan riwayat check agar tidak muncul popup saat menerima OK:RESET
    clearCheckResults();
    
    String cmd = "${jsonEncode({"c": "reset"})}[EOF]";
    List<int> bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes);
  }

  /// Menghapus riwayat pengecekan storage agar tidak memicu popup UI lagi
  void clearCheckResults() {
    _checkResults = null;
    _checkBuffer = "";
    notifyListeners();
  }

  /// Kirim perintah CHECK ke ESP32 untuk membaca semua file LittleFS
  Future<void> sendCheck() async {
    if (_lirikCharacteristic == null) {
      _lastStatus = "ERR:NOT_CONNECTED";
      notifyListeners();
      return;
    }

    // Reset state sebelum memulai
    _isChecking = true;
    _checkBuffer = "";
    _checkResults = null; // Penting: null menandakan sedang proses
    notifyListeners();

    // Tambahkan Timeout 10 detik
    Future.delayed(const Duration(seconds: 10), () {
      if (_isChecking && _checkResults == null) {
        debugPrint('[BLE-CHECK] TIMEOUT: 10 seconds pass without response.');
        _isChecking = false;
        _lastStatus = "ERR:TIMEOUT";
        notifyListeners();
      }
    });

    debugPrint('[BLE-CHECK] Sending CHECK command to ESP32...');
    String cmd = "${jsonEncode({"c": "check"})}[EOF]";
    List<int> bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes);
    debugPrint('[BLE-CHECK] CHECK command sent, waiting for response...');
  }

  /// Reset state CHECK jika terjadi timeout atau user batal
  void cancelCheck() {
    _isChecking = false;
    _checkBuffer = "";
    _checkResults = [];
    notifyListeners();
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
    _cleanupLocal();
  }

  void _cleanupLocal() {
    _statusSub?.cancel();
    _statusSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _connectedDevice = null;
    _lirikCharacteristic = null;
    _lastStatus = "";
    _isChecking = false;
    _checkBuffer = "";
    _checkResults = null;
    notifyListeners();
  }
}
