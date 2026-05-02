# 📋 Implementation Plan: Dynamic Slots System (v2.0)

> **Project:** ESP32-S3 Lirik Sync V2  
> **Target:** Sistem slot deret dinamis dengan manajemen memori adaptif  
> **Tanggal:** 13 April 2026  
> **Status:** 🟡 Draft — Menunggu review

---

## 1. Kondisi Sistem Saat Ini

### 1.1 Hardware

| Komponen | Spesifikasi |
|----------|-------------|
| Board | ESP32-S3 (4D Systems Gen4 R8N16) |
| Flash | 16MB (QIO) |
| PSRAM | 8MB (OPI) — **sudah terdeteksi** |
| Layar | ST7735 128x160 via HSPI |
| Audio | DFPlayer Mini via SoftwareSerial |
| RTC | DS3231 via I2C (pin 37/38) |
| Storage | LittleFS (`min_spiffs.csv` partition) |

### 1.2 Arsitektur Kode Firmware (ESP32)

```
ESP32S3lirik2.ino          → Main setup/loop, UI, lirik engine
├── ble_server.ino         → BLE sync (Core 0 FreeRTOS worker task)
├── littlefs_handler.ino   → Read/write deret JSON files
├── readRTC.ino            → Baca jam dari DS3231
├── autodetect_state_df.ino→ Cek status DFPlayer
├── nextp.ino              → Navigasi deret maju
├── previouse.ino          → Navigasi deret mundur
├── oke.ino                → Play/pause handler  
├── home.ino               → Menu navigation
├── mode.ino               → Mode switching (Kanan/Kiri/All)
├── volume.ino             → Volume control
├── new_bat.ino            → Battery management
├── tampiljam.ino          → Tampilan jam di layar
└── begin.ino              → Splash screen
```

### 1.3 Arsitektur Kode Flutter (Mobile App)

```
lib/
├── main.dart                          → Entry point + Provider setup
├── models/
│   ├── deret.dart                     → Model data 1 deret (slot, words, toJson)
│   └── word_entry.dart                → Model 1 kata (timestampMs, word)
├── providers/
│   ├── ble_provider.dart              → BLE connection, write/check/reset/version
│   ├── workspace_provider.dart        → Manage list deret, buildBulkJson, import
│   ├── lyric_update_provider.dart     → Cloud update logic
│   ├── locale_provider.dart           → Multi-language
│   └── theme_provider.dart            → Dark/light mode
├── screens/
│   ├── home_screen.dart               → Main workspace UI (list 10 slot)
│   ├── deret_editor_screen.dart       → Editor lirik per-slot
│   ├── ble_sync_screen.dart           → UI sinkronisasi BLE
│   ├── cloud_update_screen.dart       → Import data dari Supabase
│   ├── settings_screen.dart           → Pengaturan (offset, reset)
│   ├── main_shell.dart                → Bottom navigation container
│   └── splash_screen.dart             → Loading screen
└── services/
    ├── lyric_update_service.dart       → Supabase cloud fetch
    └── spike_detector.dart            → Audio spike detection
```

### 1.4 Masalah Yang Diidentifikasi

| # | Masalah | Lokasi | Dampak |
|---|---------|--------|--------|
| 1 | Batas deret hardcoded `10` di firmware | `selanjutnya()`, `sebelumnya()`, `showSyncingUI()` | Tidak bisa navigasi slot > 10 |
| 2 | Batas deret hardcoded `10` di Flutter | `workspace_provider.dart` line 32, `deret.dart` comment | Flutter hanya buat 10 slot |
| 3 | Import cloud hardcoded max slot 10 | `importFromCloudJson()` line 125 | `slotNum > 10` diabaikan |
| 4 | Loop check LittleFS cek 1-10 saja | `setup()` line 254 | Slot 11+ tidak terdeteksi |
| 5 | `deleteAllDeretFiles()` jangkauan maks 20 | `littlefs_handler.ino` line 118 | Inkonsisten |
| 6 | Progress bar sync hardcoded `/10` | `showSyncingUI()` line 588 | Bar tidak akurat jika > 10 |
| 7 | PSRAM threshold hardcoded / tidak ada | — | Risiko crash, tidak adaptif jika upgrade HW |
| 8 | Tidak ada memory reporting ke Flutter | — | User tidak tahu kapasitas tersisa |

---

## 2. Arsitektur Target

### 2.1 Alur Boot Baru (Firmware)

```
┌─────────────────────────────────────────────────────────────┐
│                     BOOT SEQUENCE                            │
│                                                              │
│  1. Serial.begin(115200)                                     │
│  2. ★ initMemoryProfile()                                    │
│     → totalPsramSize = ESP.getPsramSize()    // DINAMIS!     │
│     → safePsramThreshold = totalPsramSize * 9 / 10  // 90%  │
│     → Print diagnostics                                      │
│  3. Init TFT, GPIO, DFPlayer                                 │
│  4. Init LittleFS                                            │
│  5. ★ activeDaretCount = scanDeretSlots()                    │
│  6. Init BLE                                                 │
│  7. Print summary (memori + slot count)                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Alur Sync Baru (Flutter → ESP32)

```
┌──────────────┐        BLE WRITE         ┌───────────────────┐
│  Flutter App  │ ──────────────────────▶  │  ESP32 Firmware    │
│               │  JSON [{d:1,...},...]     │                    │
│  • N slot     │  + [EOF]                 │  parseBlePayload() │
│  • Dinamis    │                          │  ↓                 │
│               │        BLE NOTIFY        │  processDeret()    │
│               │ ◀──────────────────────  │  ↓                 │
│  lastStatus   │  "OK:15/15"             │  scanDeretSlots()  │
│  = "OK:15/15" │                          │  → activeDaretCount│
│               │                          │                    │
│  update ver   │  @SET_VERSION:v2         │  NVS save          │
│               │ ──────────────────────▶  │                    │
└──────────────┘                          └───────────────────┘
```

### 2.3 Variabel Global Baru (Firmware)

```cpp
// === Dynamic Memory Profile (ADAPTIF — bukan hardcoded!) ===
size_t totalPsramSize = 0;           // Diisi saat boot dari ESP.getPsramSize()
size_t safePsramThreshold = 0;       // 90% dari totalPsramSize
size_t totalFlashSize = 0;           // LittleFS total capacity
const size_t SAFE_FLASH_MIN = 50 * 1024; // Minimal 50KB sisa flash
const size_t SAFE_HEAP_MIN = 32768;  // Minimal 32KB internal heap

// === Dynamic Slot Management ===
int activeDaretCount = 10;           // Default fallback (di-update saat boot & sync)
```

---

## 3. Fase Implementasi — FIRMWARE (ESP32)

### Fase 1: Stabilisasi Boot (✅ Sudah Selesai)

- [x] PSRAM terdeteksi (`qio_opi`, `flash_mode = qio`)
- [x] Serial baud rate sinkron 115200
- [x] Memory diagnostics di awal `setup()`
- [x] USB CDC flags aktif
- [x] `platformio.ini` sudah menggunakan `-DBOARD_HAS_PSRAM`

### Fase 2: Adaptive Memory Profile

> **Goal:** Semua threshold memori dihitung dari ukuran PSRAM sesungguhnya yang terdeteksi saat boot. Jika di kemudian hari PSRAM di-upgrade ke 16MB, threshold 90% otomatis menyesuaikan tanpa ubah kode.

#### 2a. Tambah variabel global di `ESP32S3lirik2.ino`

```cpp
// Tambah setelah deklarasi variabel lain (sebelum forward declarations):

// === Dynamic Memory Profile ===
size_t totalPsramSize = 0;
size_t safePsramThreshold = 0;       // 90% usage = stop allocating
size_t totalFlashSize = 0;
const size_t SAFE_FLASH_MIN = 50 * 1024;
const size_t SAFE_HEAP_MIN = 32768;

// === Dynamic Slot Management ===
int activeDaretCount = 10;
```

#### 2b. Tambah fungsi `initMemoryProfile()` di `ESP32S3lirik2.ino`

```cpp
/**
 * Baca kapasitas PSRAM yang sesungguhnya dari hardware saat boot.
 * Threshold 90% dihitung secara dinamis — adaptif terhadap upgrade HW.
 * 
 * Contoh:
 *   PSRAM 8MB  → threshold = 7.2MB (sisa min 800KB)
 *   PSRAM 16MB → threshold = 14.4MB (sisa min 1.6MB)
 */
void initMemoryProfile() {
    totalPsramSize = ESP.getPsramSize();
    safePsramThreshold = totalPsramSize / 10;  // 10% dari total = batas sisa minimum
    
    Serial.println("\n========= MEMORY PROFILE =========");
    Serial.printf("  Heap Total  : %u bytes\n", ESP.getHeapSize());
    Serial.printf("  Heap Free   : %u bytes\n", ESP.getFreeHeap());
    Serial.printf("  PSRAM Total : %u bytes (%.1f MB)\n", totalPsramSize, totalPsramSize / 1048576.0);
    Serial.printf("  PSRAM Free  : %u bytes\n", ESP.getFreePsram());
    Serial.printf("  PSRAM Gate  : %u bytes (10%% reserved)\n", safePsramThreshold);
    Serial.println("==================================\n");
}
```

#### 2c. Panggil di awal `setup()` — SEBELUM init hardware lainnya

```cpp
void setup() {
    Serial.begin(115200);
    delay(1000);
    
    initMemoryProfile();  // ★ PERTAMA: baca kapasitas memori
    
    // ... lanjut init TFT, GPIO, dll
}
```

#### 2d. Tambah forward declaration

```cpp
void initMemoryProfile();
int scanDeretSlots();
bool checkMemorySafety();
```

### Fase 3: Dynamic Deret Counter

> **Goal:** `activeDaretCount` otomatis terisi dari slot tertinggi di LittleFS

#### 3a. Tambah fungsi `scanDeretSlots()` di `littlefs_handler.ino`

```cpp
/**
 * Scan LittleFS untuk menemukan slot deret tertinggi yang terisi.
 * Return: nomor slot tertinggi (bukan jumlah total file).
 * 
 * Contoh:
 *   File: deret_3.json, deret_7.json → return 7
 *   File: kosong                      → return 10 (default minimum)
 */
int scanDeretSlots() {
    int maxSlot = 0;
    int fileCount = 0;
    
    for (int i = 1; i <= 50; i++) {
        String filename = "/lirik/deret_" + String(i) + ".json";
        if (LittleFS.exists(filename)) {
            maxSlot = i;
            fileCount++;
        }
    }
    
    // Minimum 10 agar navigasi UI tetap konsisten saat LittleFS kosong
    if (maxSlot < 10) maxSlot = 10;
    
    Serial.printf("[LFS-SCAN] Files found: %d, Highest slot: %d\n", fileCount, maxSlot);
    return maxSlot;
}
```

#### 3b. Panggil di `setup()` setelah `initLittleFS()`

```cpp
if (initLittleFS()) {
    // ... existing code ...
    
    // ★ Dynamic slot count
    activeDaretCount = scanDeretSlots();
    
    // ★ Update flash diagnostics (sekarang LittleFS sudah mount)
    totalFlashSize = LittleFS.totalBytes();
    
    Serial.println("[SETUP] === STORAGE SUMMARY ===");
    Serial.printf("[SETUP]   Active Derets : %d\n", activeDaretCount);
    Serial.printf("[SETUP]   Flash Total   : %u bytes\n", totalFlashSize);
    Serial.printf("[SETUP]   Flash Used    : %u bytes\n", LittleFS.usedBytes());
    Serial.printf("[SETUP]   Flash Free    : %u bytes\n", totalFlashSize - LittleFS.usedBytes());
    Serial.println("[SETUP] ============================");
}
```

### Fase 4: Adaptive UI Navigation

#### 4a. `selanjutnya()` — file `ESP32S3lirik2.ino`

```diff
  deret++;
- if (deret >= 11)
+ if (deret > activeDaretCount)
    deret = 1;
```

#### 4b. `sebelumnya()` — file `ESP32S3lirik2.ino`

```diff
  deret--;
  if (deret <= 0)
-   deret = 10;
+   deret = activeDaretCount;
```

#### 4c. `showSyncingUI()` — file `ESP32S3lirik2.ino`

```diff
  // Progress Bar
  tft.drawRect(15, 95, 98, 10, ST77XX_WHITE);
- int progressW = (slot * 94) / 10;
+ int progressW = (slot * 94) / max(total, 1);
  tft.fillRect(17, 97, progressW, 6, ST77XX_CYAN);
```

#### 4d. Boot scan di `setup()` — ganti hardcoded loop

```diff
  Serial.println("[SETUP] Checking LittleFS deret availability:");
- for (int i = 1; i <= 10; i++) {
+ for (int i = 1; i <= activeDaretCount; i++) {
```

### Fase 5: Re-scan Setelah BLE Sync

#### 5a. Di `ble_server.ino` → `parseBlePayload()`, sebelum `hideSyncingUI()`

```cpp
// Re-scan slot setelah sinkronisasi selesai
extern int activeDaretCount;
extern int scanDeretSlots();
activeDaretCount = scanDeretSlots();
Serial.printf("[BLE-SYNC] Updated activeDaretCount: %d\n", activeDaretCount);
```

#### 5b. Di `factoryReset()`

```cpp
void factoryReset() {
    deleteAllDeretFiles();
    extern int activeDaretCount;
    activeDaretCount = 10;
    Serial.println("[BLE-RESET] activeDaretCount reset to 10");
}
```

#### 5c. Perluas jangkauan `deleteAllDeretFiles()`

```diff
- for (int i = 1; i <= 20; i++) {
+ for (int i = 1; i <= 50; i++) {
```

### Fase 6: PSRAM Safety Gate

> **Goal:** Cek memori sebelum alokasi berat. Threshold DINAMIS berdasarkan PSRAM fisik yang terdeteksi saat boot — BUKAN angka literal.

#### 6a. Tambah fungsi `checkMemorySafety()` di `littlefs_handler.ino`

```cpp
/**
 * Cek apakah memori masih aman untuk operasi berat (load deret, parse JSON).
 * 
 * Threshold dihitung DINAMIS dari initMemoryProfile():
 *   - safePsramThreshold = 10% dari PSRAM fisik (dicadangkan)
 *   - SAFE_HEAP_MIN = 32KB internal heap minimum
 *   - SAFE_FLASH_MIN = 50KB flash minimum
 * 
 * Jika PSRAM 8MB  → cadangan 800KB, boleh pakai 7.2MB
 * Jika PSRAM 16MB → cadangan 1.6MB, boleh pakai 14.4MB
 * 
 * Returns: true = aman, false = berbahaya (jangan alokasi!)
 */
bool checkMemorySafety() {
    extern size_t totalPsramSize;
    extern size_t safePsramThreshold;
    extern const size_t SAFE_HEAP_MIN;
    extern const size_t SAFE_FLASH_MIN;
    
    size_t freePsram = ESP.getFreePsram();
    size_t freeHeap = ESP.getFreeHeap();
    size_t freeFlash = LittleFS.totalBytes() - LittleFS.usedBytes();
    
    Serial.println("[MEM-CHECK] === Safety Gate ===");
    Serial.printf("[MEM-CHECK]   PSRAM Free : %u / Min Reserved: %u\n", freePsram, safePsramThreshold);
    Serial.printf("[MEM-CHECK]   Heap Free  : %u / Min: %u\n", freeHeap, SAFE_HEAP_MIN);
    Serial.printf("[MEM-CHECK]   Flash Free : %u / Min: %u\n", freeFlash, SAFE_FLASH_MIN);
    
    if (freePsram < safePsramThreshold) {
        Serial.println("[MEM-CHECK] ⛔ BLOCKED: PSRAM usage > 90%!");
        return false;
    }
    if (freeHeap < SAFE_HEAP_MIN) {
        Serial.println("[MEM-CHECK] ⛔ BLOCKED: Internal heap critical!");
        return false;
    }
    if (freeFlash < SAFE_FLASH_MIN) {
        Serial.println("[MEM-CHECK] ⛔ BLOCKED: Flash storage almost full!");
        return false;
    }
    
    Serial.println("[MEM-CHECK] ✅ Memory OK.");
    return true;
}
```

#### 6b. Integrasikan di `loadDeretFromLittleFS()`

```cpp
Word *loadDeretFromLittleFS(int slot) {
    if (!checkMemorySafety()) {
        Serial.println("[LFS-LOAD] BLOCKED: Insufficient memory!");
        return NULL;
    }
    // ... lanjut load seperti biasa
}
```

#### 6c. Integrasikan di `processDeret()` (BLE sync) — `ble_server.ino`

```cpp
bool processDeret(JsonObject deret) {
    if (!checkMemorySafety()) {
        Serial.println("[BLE-PROC] BLOCKED: Memory full, skipping slot!");
        notifyStatus("ERR:MEM_FULL");
        return false;
    }
    // ... lanjut proses seperti biasa
}
```

---

## 4. Fase Implementasi — FLUTTER (Mobile App)

### Fase 7: Dynamic Slot List di Workspace

> **Goal:** Hapus batas hardcoded 10 slot. User bisa menambah/mengurangi deret secara bebas.

#### 7a. `workspace_provider.dart` — Hapus hardcoded init

```diff
  void _initDefaultDerets() {
-   // PRD mentions default 10 derets.
-   for (int i = 1; i <= 10; i++) {
-     _derets.add(Deret(slotNumber: i));
-   }
+   // Default 10 deret saat pertama kali, tapi bisa ditambah/kurangi
+   for (int i = 1; i <= 10; i++) {
+     _derets.add(Deret(slotNumber: i));
+   }
    notifyListeners();
  }
```

> **Catatan:** `_initDefaultDerets()` tetap membuat 10 slot default, tapi fungsi `addDeret()` yang sudah ada memungkinkan user menambah slot baru melebihi 10. Yang perlu diperbaiki adalah validasi di tempat lain.

#### 7b. `workspace_provider.dart` — Hapus batas import cloud

```diff
  void importFromCloudJson(String jsonString, {Map<int, String>? audioPaths}) {
    // ...
      final slotNum = int.tryParse(key.replaceAll('deret_', ''));
-     if (slotNum == null || slotNum < 1 || slotNum > 10) continue;
+     if (slotNum == null || slotNum < 1 || slotNum > 50) continue;
      
+     // Auto-expand list jika slot baru lebih tinggi dari yang ada
+     while (_derets.length < slotNum) {
+       _derets.add(Deret(slotNumber: _derets.length + 1));
+     }
    // ...
  }
```

#### 7c. `home_screen.dart` — Tambah tombol "Add Deret"

Di bagian bawah list deret pada `home_screen.dart`, tambahkan tombol FAB atau `ListTile` yang memanggil `workspace.addDeret()` agar user bisa menambah slot baru secara visual.

```dart
// Di akhir ListView deret:
ListTile(
  leading: const Icon(Icons.add_circle_outline),
  title: Text(AppLocalizations.of(context)!.addDeret),
  onTap: () => workspace.addDeret(),
),
```

### Fase 8: BLE Memory Report (Opsional)

> **Goal:** ESP32 melaporkan status memorinya ke Flutter agar user tahu kapasitas tersisa.

#### 8a. Tambah command `@GET_MEMORY` di `ble_server.ino`

```cpp
// Di parseBlePayload(), tambahkan:
if (payload.startsWith("@GET_MEMORY")) {
    extern size_t totalPsramSize;
    extern size_t safePsramThreshold;
    
    String memReport = String("{\"psram_total\":") + String(totalPsramSize) +
                       ",\"psram_free\":" + String(ESP.getFreePsram()) +
                       ",\"psram_gate\":" + String(safePsramThreshold) +
                       ",\"heap_free\":" + String(ESP.getFreeHeap()) +
                       ",\"flash_total\":" + String(LittleFS.totalBytes()) +
                       ",\"flash_free\":" + String(LittleFS.totalBytes() - LittleFS.usedBytes()) +
                       ",\"slots\":" + String(activeDaretCount) + "}";
    notifyStatus(memReport.c_str());
    return;
}
```

#### 8b. Tambah handler di `ble_provider.dart`

```dart
// Model baru:
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
  
  DeviceMemoryInfo.fromJson(Map<String, dynamic> json)
    : psramTotal = json['psram_total'] ?? 0,
      psramFree = json['psram_free'] ?? 0,
      psramGate = json['psram_gate'] ?? 0,
      heapFree = json['heap_free'] ?? 0,
      flashTotal = json['flash_total'] ?? 0,
      flashFree = json['flash_free'] ?? 0,
      slots = json['slots'] ?? 10;
}
```

#### 8c. UI di `ble_sync_screen.dart` — Tampilkan memory bar

Saat terhubung ke ESP32, tampilkan kartu info:
```
┌─────────────────────────────┐
│  📊 Device Memory           │
│  PSRAM: ████████░░ 78%      │
│  Flash: ██████░░░░ 62%      │
│  Slots: 15 aktif            │
└─────────────────────────────┘
```

### Fase 9: Persistensi Workspace ke SharedPreferences

> **Goal:** Workspace Flutter yang sudah ditambah/diubah setelah ditutup tidak hilang.

#### 9a. Simpan state deret saat berubah

```dart
// Di workspace_provider.dart:
Future<void> _saveDerets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _derets.map((d) => {
      'slot': d.slotNumber,
      'title': d.displayTitle,
      'synced': d.isSynced,
      'wordCount': d.words.length,
    }).toList();
    await prefs.setString('saved_derets', jsonEncode(jsonList));
}
```

#### 9b. Restore saat startup

```dart
Future<void> _loadDerets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_derets');
    if (saved != null) {
      // Restore dari saved state
    } else {
      _initDefaultDerets(); // Pertama kali: 10 slot default
    }
}
```

---

## 5. Daftar Lengkap File Yang Berubah

### Firmware (ESP32)

| File | Perubahan | Fase |
|------|-----------|------|
| `ESP32S3lirik2.ino` | `initMemoryProfile()`, variabel global memori, `activeDaretCount`, update `selanjutnya()`, `sebelumnya()`, `showSyncingUI()`, `setup()` | 2, 3, 4 |
| `littlefs_handler.ino` | `scanDeretSlots()`, `checkMemorySafety()`, perluas delete range | 3, 5, 6 |
| `ble_server.ino` | Re-scan setelah sync, factory reset update, `@GET_MEMORY` command | 5, 8 |

### Flutter (Mobile App)

| File | Perubahan | Fase |
|------|-----------|------|
| `workspace_provider.dart` | Hapus batas import `slotNum > 10`, auto-expand list, persistensi | 7, 9 |
| `ble_provider.dart` | `DeviceMemoryInfo` model, `getDeviceMemory()` command | 8 |
| `home_screen.dart` | Tombol "Add Deret" di akhir list | 7 |
| `ble_sync_screen.dart` | Tampilan memory bar ESP32 (opsional) | 8 |
| `deret.dart` | Tidak berubah (sudah support slot > 10) | — |

---

## 6. Diagram Alur Memori Baru

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOOT: initMemoryProfile()                     │
│                                                                  │
│   totalPsramSize = ESP.getPsramSize()                            │
│   ┌──────────────────────────────────────┐                       │
│   │  Contoh: 8,388,608 bytes (8MB)       │                       │
│   └──────────────────────────────────────┘                       │
│                    │                                              │
│                    ▼                                              │
│   safePsramThreshold = totalPsramSize / 10                       │
│   ┌──────────────────────────────────────┐                       │
│   │  = 838,860 bytes (~800KB cadangan)   │                       │
│   └──────────────────────────────────────┘                       │
│                                                                  │
│   ═══════════════════════════════════════                         │
│   RUNTIME: checkMemorySafety()                                   │
│   ═══════════════════════════════════════                         │
│                                                                  │
│   freePsram = ESP.getFreePsram()                                 │
│                                                                  │
│   if (freePsram < safePsramThreshold)                            │
│       → ⛔ BLOCK operasi (return false)                          │
│       → User diberi notifikasi "memory full"                     │
│   else                                                           │
│       → ✅ Lanjutkan operasi                                     │
│                                                                  │
│   ┌────────────────────────────────────────────────────────────┐ │
│   │ PSRAM 8MB:  ████████████████████████████░░░  90% → STOP   │ │
│   │ PSRAM 16MB: ████████████████████████████░░░  90% → STOP   │ │
│   │             ↑ Zona aman                  ↑ Cadangan 10%   │ │
│   └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Strategi Migrasi

> **PENTING:** Semua perubahan bersifat **backward-compatible**.

### Prinsip:
- Jika LittleFS kosong → `activeDaretCount = 10` (fallback)
- Jika PSRAM tidak terdeteksi → `safePsramThreshold = 0` (gate non-aktif)
- Format JSON LittleFS **tidak berubah** → file lama tetap kompatibel
- Flutter workspace lama tetap berfungsi (10 slot default)

### Urutan Eksekusi Yang Aman:

| Urutan | Aksi | Risiko |
|--------|------|--------|
| 1 | ✅ Pastikan boot stabil (Fase 1) | — |
| 2 | Tambah `initMemoryProfile()` di `ESP32S3lirik2.ino` | Sangat rendah — hanya print |
| 3 | Tambah `scanDeretSlots()` di `littlefs_handler.ino` | Sangat rendah — read-only |
| 4 | Tambah `activeDaretCount` + panggil scanner di `setup()` | Rendah |
| 5 | Update navigasi firmware (`selanjutnya`, `sebelumnya`, UI) | Rendah |
| 6 | Update `ble_server.ino` re-scan + factory reset | Rendah |
| 7 | Tambah `checkMemorySafety()` | Rendah — hanya guard |
| 8 | Update Flutter `workspace_provider.dart` | Rendah |
| 9 | Tambah tombol "Add Deret" di Flutter | Rendah |
| 10 | (Opsional) BLE Memory Report | Independen |
| 11 | (Opsional) Persistensi workspace Flutter | Independen |

---

## 8. Testing Checklist

### Firmware

| # | Test Case | Expected Result |
|---|-----------|-----------------|
| 1 | Boot tanpa file LittleFS | `activeDaretCount = 10`, memori tercetak |
| 2 | Boot dengan 5 file (deret 1-5) | `activeDaretCount = 10` (min fallback) |
| 3 | Boot dengan 15 file (deret 1-15) | `activeDaretCount = 15` |
| 4 | Boot dengan gap (deret 1, 3, 12) | `activeDaretCount = 12` |
| 5 | Navigasi `selanjutnya()` di slot terakhir | Wrap ke deret 1 |
| 6 | Navigasi `sebelumnya()` di deret 1 | Wrap ke `activeDaretCount` |
| 7 | BLE sync 15 deret baru | `activeDaretCount` update ke 15 |
| 8 | Factory reset via BLE | `activeDaretCount` kembali ke 10, semua file hapus |
| 9 | Progress bar sync 15 slot | Bar proporsional `slot/15` |
| 10 | Load deret saat PSRAM < 10% | `checkMemorySafety()` return false, tidak crash |
| 11 | Boot pada PSRAM 8MB vs 16MB | Threshold adaptif (800KB vs 1.6MB) |

### Flutter

| # | Test Case | Expected Result |
|---|-----------|-----------------|
| 12 | Default startup (pertama kali) | 10 slot deret tampil |
| 13 | Tekan "Add Deret" 5x | 15 slot tampil, slotNumber 11-15 |
| 14 | Sync 15 deret ke ESP32 | JSON payload berisi 15 objek, progress bar akurat |
| 15 | Import cloud dengan 15 deret | List auto-expand, semua terisi |
| 16 | Hapus deret + undo | Slot terhapus, bisa di-restore |
| 17 | BLE memory report (jika diimplementasi) | Tampilan bar PSRAM/Flash muncul |
| 18 | Tutup & buka app (jika persistensi aktif) | Workspace tetap utuh |

---

## 9. Rollback Plan

### Jika firmware bermasalah:
1. Kembalikan `activeDaretCount` ke konstanta `10`
2. Kembalikan `selanjutnya()` ke `if (deret >= 11)`
3. Kembalikan `sebelumnya()` ke `deret = 10`
4. Hapus fungsi `scanDeretSlots()` dan `checkMemorySafety()`
5. Hapus variabel `totalPsramSize` dan `safePsramThreshold`

### Jika Flutter bermasalah:
1. Kembalikan batas `slotNum > 10` di `importFromCloudJson()`
2. Kembalikan `_initDefaultDerets()` ke hardcoded 10

> **Catatan:** Tidak ada perubahan format file JSON. File LittleFS dan data workspace yang sudah tersimpan tetap kompatibel.

---

## 10. Prioritas Implementasi

| Prioritas | Fase | Deskripsi |
|-----------|------|-----------|
| 🔴 Tinggi | 2 | Adaptive Memory Profile — pondasi semua fitur lain |
| 🔴 Tinggi | 3 | Dynamic Deret Counter — core feature |
| 🔴 Tinggi | 4 | Adaptive UI Navigation — UX firmware |
| 🟡 Sedang | 5 | Re-scan setelah BLE Sync — konsistensi data |
| 🟡 Sedang | 6 | PSRAM Safety Gate — perlindungan crash |
| 🟡 Sedang | 7 | Flutter dynamic slots — UX mobile |
| 🟢 Rendah | 8 | BLE Memory Report — fitur monitoring opsional |
| 🟢 Rendah | 9 | Persistensi workspace — kenyamanan user |

---

*Plan v2.0 — Lirik Sync V2 Dynamic Slots + Adaptive Memory + Flutter Integration*
