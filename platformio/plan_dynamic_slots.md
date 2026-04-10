# 🧬 Blueprint: Ekspansi Dinamis Deret & Manajemen Memori PSRAM

> **Versi:** 1.0  
> **Tanggal:** 10 April 2026  
> **Tujuan:** Menghapus seluruh batasan hardcode 10 deret → Sistem dinamis berbasis memori fisik  

---

## 📐 1. Arsitektur Sistem Baru

### Prinsip Inti
```
┌──────────────────────────────────────────────────────────┐
│                    SAAT BOOTING                          │
│                                                          │
│  total_psram = ESP.getPsramSize()     ← Otomatis deteksi │
│  total_flash = LittleFS.totalBytes()  ← Otomatis deteksi │
│  batas_psram = total_psram * 0.10     ← Sisakan 10%      │
│  batas_flash = 50 * 1024              ← Sisakan 50KB     │
│  active_deret_count = getDeretCount() ← Hitung file      │
│                                                          │
│  Semua angka di atas TIDAK hardcode, melainkan dihitung   │
│  langsung dari chip. Jika chip di-upgrade → otomatis.     │
└──────────────────────────────────────────────────────────┘
```

### Alur Safety Gate (Gerbang Pengaman 90%)
```
Flutter kirim data deret baru via BLE
              │
              ▼
┌─────────────────────────────────────┐
│  ESP32: checkMemorySafety()         │
│                                     │
│  free_psram = ESP.getFreePsram()    │
│  free_flash = total - used          │
│                                     │
│  if (free_psram < batas_psram)      │
│     → TOLAK, kirim ERR:MEM_FULL    │
│                                     │
│  if (free_flash < batas_flash)      │
│     → TOLAK, kirim ERR:FLASH_FULL  │
│                                     │
│  else → LANJUTKAN simpan            │
└─────────────────────────────────────┘
              │
              ▼
Flutter terima ERR:MEM_FULL
              │
              ▼
Tampilkan Dialog: "Memori perangkat hampir penuh (>90%)"
```

---

## 🔧 2. Detail Perubahan Sisi ESP32 Firmware

### LANGKAH 1: Tambah Variabel Global Memori Adaptif
**File:** `ESP32S3lirik2.ino`  
**Lokasi:** Setelah baris 100 (area variabel global)  
**Aksi:** Tambahkan variabel baru

```cpp
// === Manajemen Memori Dinamis ===
size_t totalPsramSize = 0;       // Total PSRAM fisik (otomatis deteksi)
size_t safePsramThreshold = 0;   // Batas minimum PSRAM tersisa (10% dari total)
size_t totalFlashSize = 0;       // Total LittleFS capacity
const size_t SAFE_FLASH_MIN = 50 * 1024; // Minimal 50KB sisa flash
int activeDaretCount = 10;       // Jumlah deret aktif (dinamis, di-update saat boot)
```

---

### LANGKAH 2: Inisialisasi Diagnostik Memori di `setup()`
**File:** `ESP32S3lirik2.ino`  
**Lokasi:** Baris 240-264 (setelah `initLittleFS()` berhasil)  
**Aksi:** Ganti blok debug boot + tambah inisialisasi memori

**SEBELUM (baris 240-264):**
```cpp
if (initLittleFS()) {
    Serial.println("[SETUP] LittleFS ready for lyrics storage");
    Serial.println("[SETUP] Checking LittleFS deret availability:");
    for (int i = 1; i <= 10; i++) {                    // ← HARDCODE 10
      Serial.print("[SETUP]   Deret ");
      Serial.print(i);
      Serial.print(": ");
      Serial.println(deretExistsInLittleFS(i) ? "LittleFS ✓"
                                              : "Hardcoded (default)");
    }
  }
  ...
  Serial.println("[SETUP] System initialization COMPLETE");
  Serial.print("[SETUP] Free heap: ");
  Serial.print(ESP.getFreeHeap());
  Serial.println(" bytes");
```

**SESUDAH:**
```cpp
if (initLittleFS()) {
    Serial.println("[SETUP] LittleFS ready for lyrics storage");
    
    // === DIAGNOSTIK MEMORI ADAPTIF ===
    totalPsramSize = ESP.getPsramSize();
    safePsramThreshold = totalPsramSize / 10; // 10% dari total PSRAM
    totalFlashSize = LittleFS.totalBytes();
    activeDaretCount = getDeretCount();
    if (activeDaretCount < 1) activeDaretCount = 1; // Minimal 1 deret

    Serial.println("[SETUP] === MEMORY DIAGNOSTICS ===");
    Serial.printf("[SETUP]   PSRAM Total : %u bytes (%.1f MB)\n", totalPsramSize, totalPsramSize / 1048576.0);
    Serial.printf("[SETUP]   PSRAM Free  : %u bytes\n", ESP.getFreePsram());
    Serial.printf("[SETUP]   PSRAM Gate  : %u bytes (10%% threshold)\n", safePsramThreshold);
    Serial.printf("[SETUP]   Flash Total : %u bytes\n", totalFlashSize);
    Serial.printf("[SETUP]   Flash Used  : %u bytes\n", LittleFS.usedBytes());
    Serial.printf("[SETUP]   Flash Free  : %u bytes\n", totalFlashSize - LittleFS.usedBytes());
    Serial.printf("[SETUP]   Active Derets: %d\n", activeDaretCount);
    Serial.println("[SETUP] ==============================");

    // Debug: tampilkan deret yang ada (DINAMIS)
    Serial.println("[SETUP] Checking LittleFS deret availability:");
    for (int i = 1; i <= activeDaretCount; i++) {
      Serial.printf("[SETUP]   Deret %d: %s\n", i,
                    deretExistsInLittleFS(i) ? "LittleFS ✓" : "Empty");
    }
  }
  ...
  Serial.println("[SETUP] System initialization COMPLETE");
  Serial.printf("[SETUP] Free heap: %u bytes\n", ESP.getFreeHeap());
  Serial.printf("[SETUP] Free PSRAM: %u bytes\n", ESP.getFreePsram());
```

---

### LANGKAH 3: Buat Fungsi Safety Gate
**File:** `ESP32S3lirik2.ino`  
**Lokasi:** Sebelum fungsi `showSyncingUI()` (sekitar baris 560)  
**Aksi:** Tambahkan fungsi baru

```cpp
/**
 * Cek apakah memori masih aman untuk menyimpan deret baru.
 * Returns: true = aman, false = penuh (>90% terpakai)
 */
bool checkMemorySafety() {
    size_t freePsram = ESP.getFreePsram();
    size_t freeFlash = LittleFS.totalBytes() - LittleFS.usedBytes();
    
    Serial.println("[MEM-CHECK] === Safety Gate ===");
    Serial.printf("[MEM-CHECK]   PSRAM Free: %u / Threshold: %u\n", freePsram, safePsramThreshold);
    Serial.printf("[MEM-CHECK]   Flash Free: %u / Threshold: %u\n", freeFlash, SAFE_FLASH_MIN);
    
    if (freePsram < safePsramThreshold) {
        Serial.println("[MEM-CHECK] ⚠ BLOCKED: PSRAM usage > 90%!");
        return false;
    }
    if (freeFlash < SAFE_FLASH_MIN) {
        Serial.println("[MEM-CHECK] ⚠ BLOCKED: Flash storage almost full!");
        return false;
    }
    
    Serial.println("[MEM-CHECK] ✓ Memory OK, safe to proceed.");
    return true;
}
```

---

### LANGKAH 4: Pasang Safety Gate di BLE Parser
**File:** `ble_server.ino`  
**Lokasi:** Baris 267-270 (tepat sebelum loop `processDeret`)  
**Aksi:** Sisipkan pengecekan memori

**SEBELUM (baris 268-270):**
```cpp
    int successCount = 0;
    int failCount = 0;
    
    if (doc.is<JsonArray>()) {
```

**SESUDAH:**
```cpp
    // === SAFETY GATE: Cek memori sebelum menyimpan ===
    if (!checkMemorySafety()) {
        Serial.println("[BLE-PARSE] REJECTED: Memory threshold exceeded!");
        notifyStatus("ERR:MEM_FULL");
        isSyncing = false;
        return;
    }

    int successCount = 0;
    int failCount = 0;
    
    if (doc.is<JsonArray>()) {
```

---

### LANGKAH 5: Progress Bar Dinamis
**File:** `ESP32S3lirik2.ino`  
**Lokasi:** Baris 562 (fungsi `showSyncingUI`)  
**Aksi:** Ganti parameter pembagi hardcode

**SEBELUM (baris 578):**
```cpp
int progressW = (slot * 94) / 10; // Asumsi 10 slot total
```

**SESUDAH:**
```cpp
int progressW = (slot * 94) / max(total, 1); // Dinamis sesuai jumlah slot yang di-sync
```

---

### LANGKAH 6: Navigasi Deret Screening Dinamis
**File:** `ESP32S3lirik2.ino`

#### 6a. Fungsi `selanjutnya()` (baris 407-409)
**SEBELUM:**
```cpp
  deret++;
  if (deret >= 11)
    deret = 1;
```
**SESUDAH:**
```cpp
  deret++;
  if (deret > activeDaretCount)
    deret = 1;
```

#### 6b. Fungsi `sebelumnya()` (baris 435-437)
**SEBELUM:**
```cpp
  deret--;
  if (deret <= 0)
    deret = 10;
```
**SESUDAH:**
```cpp
  deret--;
  if (deret <= 0)
    deret = activeDaretCount;
```

---

### LANGKAH 7: Menu File TFT Dinamis
**File:** `file.ino`  
**Lokasi:** Baris 8-11  
**Aksi:** Ganti array statis dengan hitungan dinamis

**SEBELUM (baris 8-11):**
```cpp
const char* menuItems[] = {"DERET 1", "DERET 2", ..., "DERET 10"};
const int menuCount = 10;
```

**SESUDAH:**
```cpp
// Menu deret sekarang dinamis berdasarkan file LittleFS yang tersedia
int menuCount = 10; // Akan di-update saat file() dipanggil

// Buffer nama menu (digunakan saat rendering)
char menuItemBuffer[16]; // "DERET XX" max 15 char + null
```

Lalu di fungsi `file()` (baris 20-24), tambahkan refresh:
```cpp
void file(){
  menuCount = getDeretCount();
  if (menuCount < 1) menuCount = 1;
  selectedIndex = 0;
  page = 0;
  displaymenu = 1;
  posisi = 4;
  displayMenu();
}
```

Dan di fungsi `displayMenu()`, ganti cara render nama menu:
```cpp
// Di dalam loop render, ganti menuItems[index] dengan:
snprintf(menuItemBuffer, sizeof(menuItemBuffer), "DERET %d", index + 1);
canvas.print(menuItemBuffer);
```

---

### LANGKAH 8: Update `activeDaretCount` Setelah Sync
**File:** `ble_server.ino`  
**Lokasi:** Baris 309 (setelah `listLirikFiles()`)  
**Aksi:** Refresh counter

**TAMBAHKAN:**
```cpp
    listLirikFiles();
    activeDaretCount = getDeretCount(); // ← Refresh jumlah deret aktif
    if (activeDaretCount < 1) activeDaretCount = 1;
    Serial.printf("[BLE] Active deret count updated: %d\n", activeDaretCount);
```

---

## 📱 3. Detail Perubahan Sisi Flutter App

### LANGKAH 9: Hapus Filter Statis di `workspace_provider.dart`
**File:** `flutter/lib/providers/workspace_provider.dart`

#### 9a. Import cloud JSON (baris 125)
**SEBELUM:**
```dart
if (slotNum == null || slotNum < 1 || slotNum > 10) continue;
```
**SESUDAH:**
```dart
if (slotNum == null || slotNum < 1) continue; // Tanpa batas atas
```

---

### LANGKAH 10: Hapus Filter Statis di `home_screen.dart`
**File:** `flutter/lib/screens/home_screen.dart`

#### 10a. MP3 import filter (baris 109)
**SEBELUM:**
```dart
if (num >= 1 && num <= 10) {
```
**SESUDAH:**
```dart
if (num >= 1) { // Tanpa batas atas
```

#### 10b. JSON import filter (baris 144)
**SEBELUM:**
```dart
if (slotNum != null && slotNum >= 1 && slotNum <= 10) {
```
**SESUDAH:**
```dart
if (slotNum != null && slotNum >= 1) { // Tanpa batas atas
```

---

### LANGKAH 11: Download Audio Cloud Dinamis
**File:** `flutter/lib/providers/lyric_update_provider.dart`  
**Lokasi:** Baris 120

**SEBELUM:**
```dart
for (int i = 1; i <= 10; i++) {
```
**SESUDAH:**
```dart
// Hitung jumlah deret dari data.json yang sudah didownload
final deretCount = _countDeretsInJson(_downloadedDataJson ?? '');
for (int i = 1; i <= deretCount; i++) {
```

Tambahkan helper method di class yang sama:
```dart
int _countDeretsInJson(String json) {
  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return data.keys
        .where((k) => k.toLowerCase().startsWith('deret_'))
        .length;
  } catch (_) {
    return 10; // Fallback default
  }
}
```

---

### LANGKAH 12: Handle `ERR:MEM_FULL` di Flutter
**File:** `flutter/lib/screens/ble_sync_screen.dart`  
**Lokasi:** Di dalam blok `_startSync()`, setelah menerima status BLE

Di bagian yang membaca `_lastStatus` dari BLE provider, tambahkan pengecekan:
```dart
if (ble.lastStatus.contains('ERR:MEM_FULL') || 
    ble.lastStatus.contains('ERR:FLASH_FULL')) {
  throw Exception(
    l10n?.translate('memoryFull') ?? 
    'Memori perangkat hampir penuh (>90%). '
    'Hapus beberapa deret yang tidak digunakan untuk melanjutkan.'
  );
}
```

---

### LANGKAH 13: Update Model Komentar
**File:** `flutter/lib/models/deret.dart`  
**Lokasi:** Baris 4

**SEBELUM:**
```dart
// - slotNumber: Nomor deret (1-10)
```
**SESUDAH:**
```dart
// - slotNumber: Nomor deret (1-N, dinamis tanpa batas hardcode)
```

---

## ✅ 4. Checklist Eksekusi

| # | File | Langkah | Status |
|---|---|---|---|
| 1 | `ESP32S3lirik2.ino` | Tambah variabel global memori | ✅ |
| 2 | `ESP32S3lirik2.ino` | Diagnostik memori di `setup()` | ✅ |
| 3 | `ESP32S3lirik2.ino` | Buat fungsi `checkMemorySafety()` | ✅ |
| 4 | `ble_server.ino` | Pasang Safety Gate di BLE parser | ✅ |
| 5 | `ESP32S3lirik2.ino` | Progress bar dinamis (`showSyncingUI`) | ✅ |
| 6 | `ESP32S3lirik2.ino` | Navigasi `selanjutnya()` & `sebelumnya()` dinamis | ✅ |
| 7 | `file.ino` | Menu TFT dinamis (hapus array statis) | ✅ |
| 8 | `ble_server.ino` | Refresh `activeDaretCount` setelah sync | ✅ |
| 9 | `workspace_provider.dart` | Hapus filter `slotNum > 10` | ✅ |
| 10 | `home_screen.dart` | Hapus filter `num <= 10` | ✅ |
| 11 | `lyric_update_provider.dart` | Download audio cloud dinamis | ✅ |
| 12 | `ble_sync_screen.dart` | Handle `ERR:MEM_FULL` | ✅ |
| 13 | `deret.dart` | Update komentar model | ✅ |

---

## 📊 5. Kalkulasi Keamanan Memori

| Resource | Total | 90% Usage | Sisa Aman (10%) | Kapasitas Deret |
|---|---|---|---|---|
| PSRAM 8MB | 8,388,608 B | 7,549,747 B | 838,861 B | ~200+ deret |
| PSRAM 16MB* | 16,777,216 B | 15,099,494 B | 1,677,722 B | ~400+ deret |
| Flash (LittleFS) | ~1.5 MB | ~1.35 MB | ~150 KB | ~75 deret |

> *\*Jika chipset di-upgrade ke 16MB di masa depan, angka threshold otomatis menyesuaikan tanpa ubah kode.*

**Bottleneck sebenarnya:** LittleFS Flash (~1.5MB), bukan PSRAM. Setiap file `deret_X.json` berukuran rata-rata ~2KB, jadi kapasitas realistis adalah **~75 deret** sebelum flash penuh.

---

## ⚠️ 6. Catatan Penting

1. **DFPlayer Mini** mendukung hingga **99 folder × 255 file** — tidak menjadi bottleneck.
2. **Fungsi `getDeretCount()`** sudah ada di `littlefs_handler.ino` baris 133-155 dan tidak perlu dimodifikasi.
3. **Fungsi `deleteAllDeretFiles()`** sudah support hingga 20 deret (baris 118). Perlu dinaikkan ke nilai yang sama dengan batas dinamis.
4. Setelah implementasi selesai, lakukan **stress test**: tambah 15-20 deret, sync, lalu verifikasi menu TFT dan navigasi screening berjalan mulus.
