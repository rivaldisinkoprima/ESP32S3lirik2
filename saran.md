# Saran Pengembangan - Flutter & ESP32

## Analisis Batasan Deret (Slot)

Berdasarkan pengecekan menyeluruh, ditemukan **inkonsistensi** antara Flutter dan ESP32:

| Komponen | Batasan | Keterangan |
|----------|---------|-------------|
| **Flutter App** | Dinamis (bisa tambah >20) | Fitur "New Track" tidak dibatasi |
| **ESP32 Hardware Display** | **HARD LIMIT 10** | `deret >= 11` reset ke 1, `deret <= 0` reset ke 10 |
| **ESP32 LittleFS** | Support hingga 20 | Loop sampai slot 20 |

### ⚠️ Masalah Data Loss

**Flutter mengirim SEMUA deret** yang sudah sync:
```dart
// workspace_provider.dart:94-100 - TIDAK ADA BATASAN
String buildBulkJson() {
  List<Map<String, dynamic>> payload = _derets
      .where((d) => d.isSynced && d.words.isNotEmpty)
      .map((d) => d.toJson(_globalOffsetMs))
      .toList();  // ← Semua deret, tanpa limit!
  return jsonEncode(payload);
}
```

**Di ESP32 hanya diproses hingga 20**:
```cpp
// littlefs_handler.ino:247 - hanya sampai 20
for (int slot = 1; slot <= 20; slot++) {
```

**Hasilnya**:
- Flutter punya 25 deret → kirim 25 ke ESP32
- ESP32 proses hanya 20 slot pertama
- **Slot 21-25 di-flash tapi tidak disimpan → DATA LOSS!**
- User tidak tahu data mereka tidak tersimpan

---

## Flutter (Aplikasi Mobile)

| # | Kategori | Saran | Lokasi Kode | Alasan | Keuntungan |
|---|----------|-------|-------------|--------|------------|
| 1 | **Bug Fix** | **Batasi max 20 deret** di `buildBulkJson()` | `workspace_provider.dart:94` | Slot >20 tidak tersimpan di ESP32, tapi tetap dikirim | Data tidak hilang secara diam-diam |
| 2 | UI/UX | Tambah warning/slot limit indicator | `home_screen.dart:570` | User harus tahu maksimal slot | User aware terhadap batasan |
| 3 | Error Handling | Try-catch di `writeBatchJson()` | `ble_provider.dart:188` | JSON generation bisa gagal | App tidak crash |
| 4 | Error Handling | Validasi payload size sebelum kirim | `ble_provider.dart:188` | Payload >20KB bisa MTU issues | Sync stabil |
| 5 | Dependency | Lock versi dependencies | `pubspec.yaml` | Update lib bisa breaking changes | Build konsisten |
| 6 | Dependency | Hapus dependencies tidak terpakai | `pubspec.yaml` | Mengurangi APK size | APK lebih kecil |
| 7 | Testing | Unit test untuk providers | `lib/providers/` | Refactor bisa break fitur | Lebih percaya diri |
| 8 | Error Handling | Handle exception di `_autoDetectAll()` | `home_screen.dart:323` | Audio corrupt bisa crash | User tidak bingung |
| 9 | Bug Fix | Samakan batasan default (10 → 20) | `workspace_provider.dart:32` | Default 10 tidak match LittleFS | Konsisten |
| 10 | Error Handling | Try-catch di `importFromCloudJson()` | `workspace_provider.dart:115` | JSON parse error | Import aman |
| 11 | Performa | Lazy loading di BLE scan | `ble_sync_screen.dart` | Banyak device = lambat | UI responsif |
| 12 | Performa | Lebih banyak `const` widget | Semua screen | Kurangi rebuild | Smooth rendering |
| 13 | State Management | Pisahkan logic ke service class | `lib/screens/` | UI fokus ke view | Kode reusable |
| 14 | UI/UX | Skeleton loading | `cloud_update_screen.dart` | Lebih baik dari spinner | UX lebih baik |
| 15 | UI/UX | Progress indicator real-time | `ble_sync_screen.dart` | User butuh tahu progress | Tidak ada assumption |
| 16 | CI/CD | `flutter analyze` di pre-commit | Git hooks | Catch issues sebelum push | Kode bersih |
| 17 | Dokumentasi | API.md untuk protokol BLE | Root folder | Mempermudah debugging | Onboarding cepat |
| 18 | Data | Versioning schema JSON | `deret.dart` | Backward compatibility | Format baru tidak break device |
| 19 | Keamanan | Validasi input dari BLE | `ble_provider.dart:142` | Input tidak dipercaya | Mencegah malicious data |

---

## ESP32 (Platformio Hardware)

| # | Kategori | Saran | Lokasi Kode | Alasan | Keuntungan |
|---|----------|-------|-------------|--------|------------|
| 1 | **Bug Fix** | **Upgrade display ke 20 slot** | `ESP32S3lirik2.ino:408,436` | LittleFS sudah 20, display hanya 10 | Bisa gunakan kapasitas penuh |
| 2 | Error Handling | Handle `deserializeJson` error | `littlefs_handler.ino:172` | JSON corrupt crash device | Device stabil |
| 3 | Error Handling | Batasi payload max size | `ble_server.ino:210` | Payload besar overflow buffer | Tidak OOM |
| 4 | Performa | Kurangi `Serial.print()` | Semua .ino | Print lambat loop utama | Responsif |
| 5 | Arsitektur | Konsolidasikan 20+ .ino ke `src/` | Root folder | Susah navigate | Mudah maintain |
| 6 | Performa | Cache LittleFS metadata | `littlefs_handler.ino:212` | Cek file = I/O flash | Loading cepat |
| 7 | Arsitektur | Wrap variabel global ke struct | `ESP32S3lirik2.ino` | Lebih terorganisir | Kode rapih |
| 8 | State Management | Singleton class untuk state | Semua .ino | Avoid variabel global | State terkontrol |
| 9 | Performa | StaticJsonDocument fixed size | `ble_server.ino:239` | Dynamic allocation boros RAM | Hemat memori |
| 10 | Error Handling | CRC/checksum validasi data | `ble_server.ino:210` | Pastikan data valid | Data integrity |
| 11 | Testing | Mock test JSON parsing | `littlefs_handler.ino` | Parse error sering bug | Ketemu lebih awal |
| 12 | Dependency | Lock versi library | `platformio.ini` | Lib upgrade bisa break | Build stabil |
| 13 | Dokumentasi | Pinout.md untuk hardware | Root folder | Onboarding teknisi | Pemasangan mudah |
| 14 | Fitur | OTA update support | `ble_server.ino` | Update tanpa akses fisik | Mudah update |
| 15 | Fitur | Logging ke SD card | `ESP32S3lirik2.ino` | Debug di lokasi | Tidak perlu Serial |

---

## Ringkasan Prioritas

| Fase | Flutter | ESP32 |
|------|---------|-------|
| **Critical** | Batasi max 20 deret, warning ke user | Upgrade display ke 20 slot |
| **Important** | Default 10→20, unit test, error handling | JSON error, payload limit |
| **Enhancement** | Lazy loading, const, progress indicator | Cache, struct encapsulation |
| **Future** | CI/CD, API docs, versioning, security | OTA, SD logging |

---

## Rekomendasi Langkah Kerja

### Segera (Critical)
1. **Flutter**: Edit `workspace_provider.dart:94` - tambahkan `.where((d) => d.slotNumber <= 20)` sebelum mapping
2. **Flutter**: Tambah indicator "Slot X/20" di home screen
3. **ESP32**: Update `ESP32S3lirik2.ino:408,436` dari 11→21 dan 10→20

### Pleasant
1. Upgrade display ESP32 ke 20 slot (follow LittleFS)
2. Default Flutter buat 20 deret instead of 10
3. Tambah slot selector UI di hardware (tombol untuk akses slot 11-20)
