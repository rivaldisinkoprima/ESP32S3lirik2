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
  String? _hardwareVersion; // Dibaca dari BleProvider (ESP32 NVS), BUKAN SharedPreferences
  String? _downloadedDataJson;
  String? _errorMessage;
  /// Map nomor deret ke path file audio lokal (misal: {1: '/data/user/.../001.mp3'})
  final Map<int, String> _downloadedAudioPaths = {};

  // ─── Getters ────────────────────────────────────────────────────────────────────
  UpdateScreenState get state => _state;
  String? get serverVersion => _serverVersion;
  String? get hardwareVersion => _hardwareVersion;
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
  // ──────────────────────────────────────────────────────────────────────────────

  /// Dipanggil oleh UI saat BleProvider melaporkan hardwareVersion berubah.
  /// Ini adalah satu-satunya jalur resmi untuk mengubah versi yang ditampilkan di layar.
  void setHardwareVersion(String? version) {
    _hardwareVersion = version;
    notifyListeners();
  }

  // ─── Public Actions ───────────────────────────────────────────────────────

  /// Dipanggil saat user menekan tombol "Periksa Pembaruan".
  /// Mendownload version.txt dan membandingkannya dengan versi hardware (NVS ESP32).
  Future<void> checkForUpdate() async {
    _setState(UpdateScreenState.checking);
    _errorMessage = null;

    try {
      final serverResult = await _service.fetchServerVersion();
      if (serverResult == null) {
        _errorMessage = 'Gagal memeriksa pembaruan. Periksa koneksi internet Anda.';
        _setState(UpdateScreenState.checkFailed);
        return;
      }

      _serverVersion = serverResult;

      // Bandingkan dengan versi hardware ESP32 (bukan SharedPreferences)
      if (_serverVersion == _hardwareVersion) {
        _setState(UpdateScreenState.upToDate);
      } else {
        _setState(UpdateScreenState.updateAvailable);
      }
    } catch (e) {
      _errorMessage = 'Gagal memeriksa pembaruan. Periksa koneksi internet Anda.';
      _setState(UpdateScreenState.checkFailed);
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

    // Step 2: Download audio per deret (1 - 50)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/cloud_audio');
      if (!await audioDir.exists()) await audioDir.create(recursive: true);

      const extensions = ['mp3', 'wav', 'm4a', 'ogg', 'aac'];

      for (int i = 1; i <= 50; i++) {
        bool audioFound = false;
        final fileNameBase = i.toString().padLeft(3, '0');

        for (final ext in extensions) {
          // Construct URL directly based on baseUrl
          // Using hardcoded _baseUrl pattern from LyricUpdateService
          final url = 'https://mrlyotncelnvnyhkhzhz.supabase.co/storage/v1/object/public/update/update/assets/$fileNameBase.$ext';
          final bytes = await _service.downloadAudio(url);
          
          if (bytes != null && bytes.isNotEmpty) {
            final localFile = File('${audioDir.path}/$fileNameBase.$ext');
            await localFile.writeAsBytes(bytes);
            _downloadedAudioPaths[i] = localFile.path;
            debugPrint('[CloudUpdate] Audio deret $i saved → ${localFile.path}');
            audioFound = true;
            break; // Stop trying extensions if found
          }
        }
        
        if (!audioFound) {
          debugPrint('[CloudUpdate] Audio deret $i tidak ditemukan di server. Menghentikan pencarian slot berikutnya.');
          break; // Berhenti mencari slot selanjutnya jika file lokal tidak ditemukan
        }
      }
    } catch (e) {
      debugPrint('[CloudUpdate] Warning: Gagal download audio: $e');
      // Tidak fatal — kata tetap diimpor meski audio tidak ada
    }

    _setState(UpdateScreenState.readyToSync);
  }

  /// Dipanggil setelah data berhasil diimpor ke Workspace.
  /// Hanya me-reset state internal provider (mereset UI).
  /// Versi TIDAK disimpan di sini — versi akan disimpan ke NVS ESP32
  /// saat proses Sync BLE berhasil (di BleSyncScreen).
  void commitUpdateSuccess() {
    _downloadedDataJson = null;
    _downloadedAudioPaths.clear();
    _setState(UpdateScreenState.idle);
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
