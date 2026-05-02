import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Status yang mungkin dikembalikan oleh [LyricUpdateService.checkForUpdate]
enum UpdateStatus {
  /// Sudah versi terbaru
  upToDate,
  /// Ada versi baru tersedia
  updateAvailable,
  /// Gagal cek (offline / server error)
  checkFailed,
}

/// Hasil pengecekan update
class UpdateCheckResult {
  final UpdateStatus status;
  /// Versi yang ada di server (hanya diisi jika [status] == [UpdateStatus.updateAvailable])
  final String? serverVersion;

  const UpdateCheckResult({required this.status, this.serverVersion});
}

/// Service untuk mengelola pengecekan dan pengunduhan aset lirik dari Supabase.
///
/// URL-URL di bawah ini harus disesuaikan dengan project Supabase Anda.
class LyricUpdateService {
  // ─── Konfigurasi URL Supabase Storage ───────────────────────────────────────
  static const String _baseUrl =
      'https://mrlyotncelnvnyhkhzhz.supabase.co/storage/v1/object/public/update/update/assets';

  /// URL publik file version.txt di Supabase Storage
  static const String _versionUrl =
      'https://mrlyotncelnvnyhkhzhz.supabase.co/storage/v1/object/public/update/update/version.txt';

  /// URL publik file data.json (lirik mentah) di Supabase Storage
  static const String _dataJsonUrl = '$_baseUrl/data.json';

  /// URL publik file audio per deret. Konvensi nama: 001.mp3, 002.mp3, ..., 010.mp3
  static String getAudioUrl(int deretNum) {
    final fileName = deretNum.toString().padLeft(3, '0');
    return '$_baseUrl/$fileName.mp3';
  }
  // ────────────────────────────────────────────────────────────────────────────

  static const String _prefKeyLocalVersion = 'lyric_local_version';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Mengecek apakah ada update lirik baru di server.
  ///
  /// Hanya mendownload [version.txt] (beberapa byte) untuk efisiensi kuota.
  /// Return [UpdateCheckResult] dengan status dan versi server jika ada update.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return const UpdateCheckResult(status: UpdateStatus.checkFailed);
      }

      final serverVersion = response.body.trim();
      final localVersion = await getLocalVersion();

      if (serverVersion == localVersion) {
        return const UpdateCheckResult(status: UpdateStatus.upToDate);
      }

      return UpdateCheckResult(
        status: UpdateStatus.updateAvailable,
        serverVersion: serverVersion,
      );
    } catch (e) {
      // Offline atau timeout — tidak crash aplikasi
      return const UpdateCheckResult(status: UpdateStatus.checkFailed);
    }
  }

  /// Mengambil versi dari server tanpa membandingkan dengan lokal.
  /// Return string versi server, atau null jika gagal.
  Future<String?> fetchServerVersion() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return response.body.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mengunduh file [data.json] dari server.
  ///
  /// File ini berisi lirik mentah (teks per deret/kata) yang akan diproses
  /// oleh aplikasi Flutter untuk menghasilkan timestamp.
  ///
  /// Return isi file sebagai [String], atau null jika gagal.
  Future<String?> downloadDataJson() async {
    try {
      final response = await http
          .get(Uri.parse(_dataJsonUrl))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mengunduh file audio MP3 dari URL yang diberikan (URL publik Supabase).
  ///
  /// Return konten file berupa [Uint8List], atau null jika gagal.
  Future<Uint8List?> downloadAudio(String audioUrl) async {
    try {
      final response = await http
          .get(Uri.parse(audioUrl))
          .timeout(const Duration(minutes: 2)); // audio bisa besar

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Menyimpan versi yang telah berhasil disinkronisasi ke perangkat ESP32.
  ///
  /// Harus dipanggil SETELAH ESP32 membalas dengan konfirmasi "OK".
  Future<void> commitVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLocalVersion, version);
  }

  /// Mengambil versi lirik yang terakhir tersinkronisasi dari penyimpanan lokal.
  ///
  /// Return '0' jika belum pernah sync.
  Future<String> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyLocalVersion) ?? '0';
  }
}
