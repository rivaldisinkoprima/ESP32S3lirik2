import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/lyric_update_service.dart';

/// State machine untuk proses Cloud Update.
enum UpdateScreenState {
  /// Belum pernah cek / idle
  idle,
  /// Sedang menghubungi server untuk cek version.txt
  checking,
  /// Server terkonfirmasi ada versi baru
  updateAvailable,
  /// Tidak ada update (sudah terbaru)
  upToDate,
  /// Gagal terhubung ke server (offline / error)
  checkFailed,
  /// Sedang mengunduh data.json & audio dari server
  downloading,
  /// Siap dikirim ke ESP32 (download selesai)
  readyToSync,
  /// Error saat download
  downloadFailed,
}

/// Provider yang mengelola state dan logika untuk fitur Cloud Update.
///
/// Komponen UI (widget) cukup mendengarkan provider ini dan
/// memanggil metode publik yang tersedia.
class LyricUpdateProvider extends ChangeNotifier {
  final LyricUpdateService _service = LyricUpdateService();

  UpdateScreenState _state = UpdateScreenState.idle;
  String? _serverVersion;
  String? _localVersion;
  String? _downloadedDataJson;
  String? _errorMessage;
  /// Map nomor deret ke path file audio lokal (misal: {1: '/data/user/.../001.mp3'})
  final Map<int, String> _downloadedAudioPaths = {};

  // ─── Getters ──────────────────────────────────────────────────────────────
  UpdateScreenState get state => _state;
  String? get serverVersion => _serverVersion;
  String? get localVersion => _localVersion;
  String? get downloadedDataJson => _downloadedDataJson;
  String? get errorMessage => _errorMessage;
  Map<int, String> get downloadedAudioPaths => Map.unmodifiable(_downloadedAudioPaths);

  /// True jika tombol "Periksa Pembaruan" seharusnya bisa ditekan
  bool get canCheck =>
      _state != UpdateScreenState.checking &&
      _state != UpdateScreenState.downloading;

  /// True jika tombol "Unduh & Proses" seharusnya aktif (ada update tersedia)
  bool get canDownload => _state == UpdateScreenState.updateAvailable;

  /// True jika data sudah siap dikirim ke ESP32 via BLE
  bool get isReadyToSync => _state == UpdateScreenState.readyToSync;
  // ──────────────────────────────────────────────────────────────────────────

  LyricUpdateProvider() {
    _loadLocalVersion();
  }

  Future<void> _loadLocalVersion() async {
    _localVersion = await _service.getLocalVersion();
    notifyListeners();
  }

  // ─── Public Actions ───────────────────────────────────────────────────────

  /// Dipanggil saat user menekan tombol "Periksa Pembaruan".
  /// Mendownload version.txt dan membandingkannya dengan versi lokal.
  Future<void> checkForUpdate() async {
    _setState(UpdateScreenState.checking);
    _errorMessage = null;

    final result = await _service.checkForUpdate();

    switch (result.status) {
      case UpdateStatus.upToDate:
        _setState(UpdateScreenState.upToDate);
        break;
      case UpdateStatus.updateAvailable:
        _serverVersion = result.serverVersion;
        _setState(UpdateScreenState.updateAvailable);
        break;
      case UpdateStatus.checkFailed:
        _errorMessage = 'Gagal memeriksa pembaruan. Periksa koneksi internet Anda.';
        _setState(UpdateScreenState.checkFailed);
        break;
    }
  }

  /// Dipanggil saat user menekan tombol "Unduh & Proses".
  /// Mendownload data.json dan semua file audio dari server ke lokal HP.
  Future<void> downloadAssets() async {
    _setState(UpdateScreenState.downloading);
    _errorMessage = null;
    _downloadedAudioPaths.clear();

    // Step 1: Download data.json
    final dataJson = await _service.downloadDataJson();
    if (dataJson == null) {
      _errorMessage = 'Gagal mengunduh data lirik. Coba lagi.';
      _setState(UpdateScreenState.downloadFailed);
      return;
    }
    _downloadedDataJson = dataJson;

    // Step 2: Download audio per deret (001.mp3 - 010.mp3)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/cloud_audio');
      if (!await audioDir.exists()) await audioDir.create(recursive: true);

      for (int i = 1; i <= 10; i++) {
        final url = LyricUpdateService.getAudioUrl(i);
        final bytes = await _service.downloadAudio(url);
        if (bytes != null && bytes.isNotEmpty) {
          final fileName = i.toString().padLeft(3, '0');
          final localFile = File('${audioDir.path}/$fileName.mp3');
          await localFile.writeAsBytes(bytes);
          _downloadedAudioPaths[i] = localFile.path;
          debugPrint('[CloudUpdate] Audio deret $i saved → ${localFile.path}');
        } else {
          debugPrint('[CloudUpdate] Audio deret $i tidak ditemukan di server, dilewati.');
        }
      }
    } catch (e) {
      debugPrint('[CloudUpdate] Warning: Gagal download audio: $e');
      // Tidak fatal — kata tetap diimpor meski audio tidak ada
    }

    _setState(UpdateScreenState.readyToSync);
  }

  /// Dipanggil setelah ESP32 membalas konfirmasi "OK" dari BLE Sync.
  /// Menyimpan versi baru secara permanen ke penyimpanan lokal HP.
  Future<void> commitUpdateSuccess() async {
    if (_serverVersion == null) return;
    await _service.commitVersion(_serverVersion!);
    _localVersion = _serverVersion;
    _serverVersion = null;
    _downloadedDataJson = null;
    _setState(UpdateScreenState.upToDate);
  }

  /// Reset state ke idle (misal: user cancel di tengah jalan)
  void reset() {
    _serverVersion = null;
    _downloadedDataJson = null;
    _downloadedAudioPaths.clear();
    _errorMessage = null;
    _setState(UpdateScreenState.idle);
  }

  // ─── Private ──────────────────────────────────────────────────────────────
  void _setState(UpdateScreenState newState) {
    _state = newState;
    notifyListeners();
  }
}
