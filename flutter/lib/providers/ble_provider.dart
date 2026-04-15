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

/// Model Fase 8: Informasi memori perangkat ESP32 via BLE
class DeviceMemoryInfo {
  final int psramTotal;
  final int psramFree;
  final int psramGate;
  final int heapFree;
  final int flashTotal;
  final int flashFree;
  final int slots;

  double get psramUsagePercent =>
      psramTotal > 0 ? ((psramTotal - psramFree) / psramTotal * 100) : 0;

  double get flashUsagePercent =>
      flashTotal > 0 ? ((flashTotal - flashFree) / flashTotal * 100) : 0;

  String get psramTotalFormatted => _formatBytes(psramTotal);
  String get psramFreeFormatted => _formatBytes(psramFree);
  String get flashTotalFormatted => _formatBytes(flashTotal);
  String get flashFreeFormatted => _formatBytes(flashFree);
  String get heapFreeFormatted => _formatBytes(heapFree);

  static String _formatBytes(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  DeviceMemoryInfo({
    required this.psramTotal,
    required this.psramFree,
    required this.psramGate,
    required this.heapFree,
    required this.flashTotal,
    required this.flashFree,
    required this.slots,
  });

  factory DeviceMemoryInfo.fromJson(Map<String, dynamic> json) {
    return DeviceMemoryInfo(
      psramTotal: json['psram_total'] as int? ?? 0,
      psramFree: json['psram_free'] as int? ?? 0,
      psramGate: json['psram_gate'] as int? ?? 0,
      heapFree: json['heap_free'] as int? ?? 0,
      flashTotal: json['flash_total'] as int? ?? 0,
      flashFree: json['flash_free'] as int? ?? 0,
      slots: json['slots'] as int? ?? 10,
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

  // --- State untuk Hardware Version (NVS) ---
  String? _hardwareVersion; // null = belum pernah terhubung/belum dibaca

  // --- State untuk Device Memory (Fase 8) ---
  DeviceMemoryInfo? _deviceMemory;
  bool _isLoadingMemory = false;

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _lirikCharacteristic != null;
  String get lastStatus => _lastStatus;
  bool get isChecking => _isChecking;
  List<DeretCheckResult>? get checkResults => _checkResults;
  String? get hardwareVersion => _hardwareVersion;
  DeviceMemoryInfo? get deviceMemory => _deviceMemory;
  bool get isLoadingMemory => _isLoadingMemory;

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

        // Auto-fetch Hardware Version dari NVS ESP32
        await readHardwareVersion();
        
        // Auto-sync Jam RTC (Opsi 3) secara background tanpa UI
        await sendRtcTimeSync();
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
      // Cek apakah ini respons memory report (JSON dengan psram_total)
      if (data.startsWith('{') && data.contains('psram_total')) {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _deviceMemory = DeviceMemoryInfo.fromJson(json);
          _isLoadingMemory = false;
          debugPrint('[BLE-MEM] Memory info received: PSRAM ${_deviceMemory!.psramUsagePercent.toStringAsFixed(1)}% used, ${_deviceMemory!.slots} slots');
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('[BLE-MEM] Error parsing memory JSON: $e');
        }
      }
      // Mode normal: status feedback singkat (OK:10/10, ERR:..., ACK_VER, atau versi)
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
    _hardwareVersion = null; // Reset saat disconnect
    _deviceMemory = null;
    _isLoadingMemory = false;
    notifyListeners();
  }

  // ─── Hardware Version Commands ──────────────────────────────────────────────

  /// Membaca versi lirik yang tersimpan di NVS ESP32 via BLE.
  /// Dipanggil otomatis setelah koneksi berhasil.
  Future<void> readHardwareVersion() async {
    if (_lirikCharacteristic == null) return;

    debugPrint('[BLE-VER] Sending @GET_VERSION...');
    final cmd = '@GET_VERSION[EOF]';
    final bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes, withoutResponse: false);

    // Tunggu respons singkat dari ESP32 (max 3 detik)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_lastStatus.isNotEmpty &&
          !_lastStatus.startsWith('OK:') &&
          !_lastStatus.startsWith('ERR:') &&
          _lastStatus != 'ACK_VER') {
        _hardwareVersion = _lastStatus;
        debugPrint('[BLE-VER] Hardware version: $_hardwareVersion');
        _lastStatus = ''; // Bersihkan agar tidak mengganggu flow lain
        notifyListeners();
        return;
      }
    }
    debugPrint('[BLE-VER] Timeout reading hardware version');
  }

  /// Menyimpan versi lirik ke NVS ESP32 setelah Sync berhasil.
  /// Dipanggil oleh BleSyncScreen setelah mendapat `OK:n/n`.
  Future<bool> sendSetVersion(String version) async {
    if (_lirikCharacteristic == null) return false;

    debugPrint('[BLE-VER] Sending @SET_VERSION:$version...');
    _lastStatus = ''; // Reset agar polling bersih
    final cmd = '@SET_VERSION:$version[EOF]';
    final bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes, withoutResponse: false);

    // Tunggu ACK_VER dari ESP32 (max 3 detik)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_lastStatus == 'ACK_VER') {
        _hardwareVersion = version;
        debugPrint('[BLE-VER] SET_VERSION acknowledged by ESP32');
        _lastStatus = ''; // Bersihkan
        notifyListeners();
        return true;
      }
    }
    debugPrint('[BLE-VER] Timeout waiting for ACK_VER');
    return false;
  }

  // ─── RTC Time Sync Commands ────────────────────────────────────────────────
  
  /// Mengirim waktu HP saat ini ke ESP32 untuk menyamakan jam RTC (DS3231)
  /// Format: @SET_TIME:HH:MM:SS
  Future<bool> sendRtcTimeSync() async {
    if (_lirikCharacteristic == null) return false;
    
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    
    debugPrint('[BLE-TIME] Sending @SET_TIME:$h:$m:$s...');
    _lastStatus = ''; 
    final cmd = '@SET_TIME:$h:$m:$s[EOF]';
    final bytes = utf8.encode(cmd);
    
    await _lirikCharacteristic!.write(bytes, withoutResponse: false);
    
    // Tunggu OK:TIME dari ESP32 (max 3 detik)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_lastStatus == 'OK:TIME') {
        debugPrint('[BLE-TIME] Time sync acknowledged by ESP32');
        _lastStatus = ''; 
        return true;
      }
    }
    debugPrint('[BLE-TIME] Timeout waiting for OK:TIME');
    return false;
  }

  // ─── Fase 8: Device Memory Report ──────────────────────────────────────

  /// Meminta laporan memori dari ESP32 via BLE command @GET_MEMORY.
  /// Hasilnya akan masuk via _handleIncomingNotify dan di-parse ke DeviceMemoryInfo.
  Future<void> getDeviceMemory() async {
    if (_lirikCharacteristic == null) return;

    _isLoadingMemory = true;
    _deviceMemory = null;
    notifyListeners();

    debugPrint('[BLE-MEM] Sending @GET_MEMORY...');
    final cmd = '@GET_MEMORY[EOF]';
    final bytes = utf8.encode(cmd);
    await _lirikCharacteristic!.write(bytes, withoutResponse: false);

    // Timeout 5 detik
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoadingMemory && _deviceMemory == null) {
        _isLoadingMemory = false;
        debugPrint('[BLE-MEM] Timeout waiting for memory report');
        notifyListeners();
      }
    });
  }
}
