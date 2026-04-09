# Dokumentasi Teknis ESP32-S3 Lirik Player + Flutter App

## Gambaran Umum Proyek

Proyek ini adalah sistem **audio screening** (pemeriksaan pendengaran) yang terdiri dari dua komponen:

1. **ESP32-S3 Lirik Player** - Perangkat keras embedded untuk memutar musik dan menampilkan lirik sinkron
2. **Flutter Mobile App** - Aplikasi Android untuk mengelola data lirik dan sinkronisasi ke perangkat ESP32
3. **Bluetooth Bridge (BLE)** - Protokol komunikasi antara mobile app dan hardware

## Dokumentasi Detail
- [**Dokumentasi Aplikasi Flutter**](./flutter/README.md) - Panduan fitur, build, dan alur kerja mobile app.
- [**Dokumentasi Firmware ESP32**](./platformio/README.md) - Detail hardware, LittleFS, dan debug logging.

### Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER MOBILE APP                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Workspace    │  │ Audio Spike  │  │   BLE       │                 │
│  │ Manager      │  │ Detection    │  │   Sync      │                 │
│  └──────────────┘  └──────────────┘  └──────────────┘                 │
│         │                   │                  │                       │
│         ├───────────────────┴──────────────────┘                       │
│         │                                                              │
│  ┌──────▼───────┐        ┌───────────────────────┐                     │
│  │ Cloud OTA    │◄───────┤ Supabase Storage (CDN)│                     │
│  │ Sync Module  │        │ - version.txt         │                     │
│  └──────────────┘        │ - data.json           │                     │
│                          └───────────────────────┘                     │
│                                                                        │
│                        Bluetooth                                       │
│                             │                                          │
└─────────────────────────────┼───────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      ESP32-S3 DEVICE                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │   TFT        │  │   DFPlayer   │  │   RTC        │                 │
│  │   Display    │  │   Mini       │  │   DS3231     │                 │
│  └──────────────┘  └──────────────┘  └──────────────┘                 │
│         │                   │                  │                       │
│         └───────────────────┴──────────────────┘                       │
│                             │                                           │
│                    ┌────────┴────────┐                                 │
│                    │   10 Deret      │                                 │
│                    │   (200 kata)    │                                 │
│                    └─────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Spesifikasi Hardware ESP32

### 1.1 Komponen Utama

| Komponen | Spesifikasi |
|----------|-------------|
| Mikrokontroler | ESP32-S3 |
| Display | TFT ST7735 128x160 piksel |
| Audio Module | DFPlayer Mini |
| RTC | DS3231 |
| Battery | Li-ion dengan ADC monitoring |

### 1.2 Pin Configuration

```
// TFT Display (SPI)
#define TFT_CS    13    // Chip Select
#define TFT_RST   12    // Reset
#define TFT_DC    11    // Data/Command
#define TFT_MOSI  10    // MOSI
#define TFT_SCK   15    // Clock

// DFPlayer Mini (Software Serial)
#define PIN_MP3_TX  36   // D7
#define PIN_MP3_RX  35   // D6

// Tombol Navigasi
int buttonNext    = 4;
int buttonPause  = 3;
int buttonHome   = 1;
int buttonPrevious = 2;
int buttonVolup  = 18;
int buttonVoldown = 9;
int buttonMode   = 6;
int buttonMDokter = 19;

// Kontrol
int TrigMic     = 8;     // Trigger Mikrofon
int TrigPower   = 21;    // Trigger Power
int TrigRlyDF   = 20;    // Trigger Relay DFPlayer

// Battery & Charging
#define PIN_CHRG  45    // Charging status
#define PIN_STBY  48    // Standby status
#define BAT_ADC_PIN 5    // Battery ADC
```

---

## 2. Flutter Mobile App

### 2.1 Fitur Utama

| Kode | Fitur | Deskripsi |
|------|-------|-----------|
| FR.A1 | Workspace Management | Mengelola 10 slot deret dengan data draft |
| FR.A2 | Audio Spike Detection | Deteksi otomatis timing kata dari file MP3 |
| FR.A3 | Validasi Karakter | Batas max 8 karakter per kata (OLED/TFT) |
| FR.A4 | SOP Warning | Peringatan wajib gunakan MP3 dari Folder 03 |
| FR.A5 | Delay Offset | Slider -500ms hingga +500ms untuk kompensasi DFPlayer |
| FR.A6 | Bluetooth Sync | Kirim data ke ESP32 via BLE (flutter_blue_plus) |
| FR.A7 | Data Chunking | Pemecahan payload 512 bytes dengan [EOF] delimiter |
| FR.A8 | Factory Reset | Kirim perintah reset (`{"c":"reset"}`) ke ESP32 |
| FR.A9 | Premium Branding | Custom Launcher Icon & Animated Splash Screen (3s) |
| FR.A10| Cloud OTA System | Download/Sinkronasi otomatis resource terbaru dari Supabase |

### 2.2 Struktur Folder Flutter

```
flutter/
├── lib/
│   ├── main.dart                 # Entry point app
│   ├── models/
│   │   ├── deret.dart             # Model data deret
│   │   └── word_entry.dart        # Model kata dengan timestamp
│   ├── providers/
│   │   ├── ble_provider.dart      # Manajemen koneksi BLE
│   │   └── workspace_provider.dart # Manajemen state workspace
│   ├── screens/
│   │   ├── splash_screen.dart     # Premium Animated Splash Screen
│   │   ├── home_screen.dart       # Menu utama workspace
│   │   ├── deret_editor_screen.dart # Editor kata per deret
│   │   ├── ble_sync_screen.dart   # Sinkronisasi Bluetooth
│   │   └── settings_screen.dart   # Pengaturan offset
│   └── services/
│       └── spike_detector.dart    # Algoritma deteksi spike
├── assets/
│   └── icon/                      # Asset icon & logo aplikasi
├── pubspec.yaml                   # Dependensi & registrasi aset
└── prd_flutter.md                 # Spesifikasi requirements
```

### 2.3 Format Data JSON

```json
{
  "d": 11,
  "name": "Deret Sebelas",
  "v": [
    {"t": 13150, "w": "SABUN"},
    {"t": 20150, "w": "KUDA"}
  ]
}
```

- `d`: Nomor slot deret (1-10)
- `name`: Nama deret (tampil di display)
- `v`: Array kata
  - `t`: Timestamp dalam milidetik (sudah + offset)
  - `w`: Kata (maks 8 karakter)

### 2.4 Cara Menggunakan Flutter App

#### a. Persiapan
1. Install Flutter SDK
2. Buka folder `flutter/`
3. Jalankan `flutter pub get`
4. Build APK: `flutter build apk`

#### b. Alur Kerja
1. **Buka App** → Tampilan Home dengan 10 deret
2. **Pilih Deret** → Klik deret untuk edit
3. **Pilih Audio** → Ambil file MP3 dari Folder 03 (bebas noise)
4. **Auto-Detect** → Tekan tombol untuk deteksi spike otomatis
5. **Edit Kata** → Sesuaikan kata & timestamp (maks 8 karakter)
6. **Simpan** → Data tersimpan di workspace
7. **Sinkronisasi** → Hubungi ESP32 via Bluetooth → Sync All

### 2.5 Cloud-Based OTA System (Supabase)

- **Platform:** Sistem ini menggunakan **Supabase Storage** sebagai CDN (gratis).
- **Arsitektur Hard-Gate OTA:** Menu Cloud Update **terkunci penuh** sebelum HP terhubung ke ESP32 via Bluetooth. Hal ini menjamin sinkronisasi versi yang 100% akurat karena aplikasi membaca **Versi Alat Aktual** langsung dari hardware.
- **Hardware Source of Truth (NVS):** Versi lirik disimpan secara permanen di partisi NVS ESP32 (menggunakan library `Preferences.h`). Data ini **imun** terhadap `Factory Reset` harian yang hanya menghapus audio di LittleFS.
- **Setup Endpoint:** Anda wajib mengganti URL endpoint bawaan menjadi Project URL Anda sendiri di `flutter/lib/services/lyric_update_service.dart`.
- **Struktur Bucket Wajib:**
  ```text
  lirik-assets/hierarki:
   └── update/
        ├── version.txt               <-- Penanda rilis terbaru
        └── assets/
             ├── data.json            <-- Payload lirik
             ├── 001.mp3 - 010.mp3    <-- File audio pendukung
  ```
- **Konfirmasi Penulisan:** Versi baru di dalam alat hanya akan diperbarui (via perintah `@SET_VERSION`) setelah transfer file `OK:10/10` terkonfirmasi sukses oleh hardware.

---

## 3. ESP32 Software (PlatformIO)

### 3.1 Struktur Program

| File | Fungsi |
|------|--------|
| `ESP32S3lirik2.ino` | Main program, setup, loop, logic `listderet` (LittleFS-first) |
| `ble_server.ino` | BLE GATT Server, JSON Chunk Reassembler, & Hardware Versioning Handling |
| `littlefs_handler.ino` | Manajemen file internal (Read/Write/Delete JSON) |
| `begin.ino` | Inisialisasi device, native screen cleanup |
| `oke.ino` | Button OK handler & playback trigger |
| `lirik.ino` | Tampilan lirik sinkron & dynamic timing logic |
| `readRTC.ino` | Pembacaan waktu dari DS3231 |
| `Mic.ino` | Mode mikrofon & monitor state |

### 3.2 State Machine

| Nilai | State | Deskripsi |
|-------|-------|-----------|
| 1 | Menu Utama | Tampilan menu dengan 3 opsi |
| 2 | Screening/Lirik | Mode putar dengan tampilan lirik |
| 3 | Atur Jam | Mode pengaturan waktu |
| 4 | Daftar File | Menu pemilihan deret |
| 5 | Detail Deret | Tampilan detail kata dalam deret |

### 3.3 Struktur Folder SD Card

```
SD Card/
├── 01/          (Mode All)
│   ├── 001.mp3  (Deret 1)
│   ├── 002.mp3  (Deret 2)
│   └── ...
├── 02/          (Mode Kiri)
│   ├── 001.mp3
│   └── ...
└── 03/          (Mode Kanan)
    ├── 001.mp3
    └── ...
```

---

## 4. Komunikasi BLE

### 4.1 UUID Service

| UUID | Deskripsi |
|------|-----------|
| `4fafc201-1fb5-459e-8fcc-c5c9c331914b` | Lirik Service |
| `beb5483e-36e1-4688-b7f5-ea07361b26a8` | Karakteristik write |

### 4.2 Format Perintah

**Sync Data:**
```json
{"payload JSON"}[EOF]
```

**Hardware Versioning:**
- `@GET_VERSION[EOF]` : HP meminta string versi dari NVS ESP32.
- `@SET_VERSION:x.y.z[EOF]` : HP memerintahkan ESP32 menyimpan versi `x.y.z` ke NVS.

**Factory Reset:**
```json
{"c": "reset"}[EOF]
```

### 4.3 Fitur Development (Debug)
Untuk memudahkan pengembangan, firmware dilengkapi dengan **Enhanced Serial Debugging** pada baud rate `9600`.
- **`[LFS]`**: Info inisialisasi & monitoring sisa memori Internal Flash.
- **`[BLE-RX]`**: Monitoring data yang masuk per chunk.
- **`[BLE-PARSE]`**: Verifikasi hasil parsing JSON.
- **`[DERET]`**: Info pemilihan sumber data (LittleFS vs Hardcoded).
- **`[MEM]`**: Monitoring penggunaan heap & pembersihan memori (RAM).

---

## 5. Troubleshooting

### 5.1 Masalah Flutter App

| Masalah | Solusi |
|---------|--------|
| Bluetooth tidak bisa scan | Pastikan izin BLUETOOTH_CONNECT & BLUETOOTH_SCAN diberikan |
| Koneksi gagal | Pastikan ESP32 dalam mode advertising |
| Sync gagal | Periksa payload tidak melebihi 5KB |

### 5.2 Masalah ESP32

| Masalah | Kemungkinan Cause | Solusi |
|---------|-------------------|--------|
| TFT tidak muncul | Wiring SPI salah | Periksa pin MOSI, SCK, CS |
| DFPlayer tidak suara | SD card tidak terbaca | Format SD card FAT16/32 |
| RTC tidak sinkron | Wiring I2C salah | Periksa SDA, SCL |
| Lirik tidak sinkron | Timing tidak sesuai | Sesuaikan offset di Flutter app |

---

## 6. Referensi Library

### Flutter
- `flutter_blue_plus: ^2.2.1` - Bluetooth LE
- `audio_waveforms: ^2.0.2` - Audio waveform extraction
- `file_picker: ^10.3.10` - File selection
- `provider: ^6.1.5+1` - State management
- `shared_preferences: ^2.5.5` - Local storage
- `http: ^1.2.2` - Supabase OTA Fetch

### ESP32
- [Adafruit ST7735](https://github.com/adafruit/Adafruit-ST7735-Library)
- [DFRobot DFPlayer Mini](https://github.com/DFRobot/DFRobotDFPlayerMini)
- [RTClib](https://github.com/adafruit/RTClib)
