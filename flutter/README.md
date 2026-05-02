# Lirik Sync - Flutter Mobile App

Aplikasi Android untuk mengelola dan menyinkronkan data lirik ke perangkat ESP32-S3 Lirik Player.

## Gambaran Umum

Aplikasi ini berfungsi sebagai **bridge wireless** untuk:
- Mengunduh versi resource terbaru (Audio & JSON) secara manual via Supabase Storage
- Merekam dan meracik lirik/kata beserta timestamp berbasis waveform file MP3
- Mengemas data menjadi JSON terenkapsulasi
- Mentransmisikan data ke perangkat ESP32 via Bluetooth NimBLE

## Fitur

| Kode | Fitur | Deskripsi |
|------|-------|-----------|
| FR.A1 | Workspace Management | Mengelola 10 slot deret dengan data draft |
| FR.A2 | Audio Spike Detection | Deteksi otomatis timing kata dari file MP3 + Mismatch Warning |
| FR.A3 | Validasi Karakter | Batas max 8 karakter per kata (OLED/TFT) |
| FR.A4 | SOP Warning | Peringatan wajib gunakan MP3 dari Folder 03 (bebas noise) |
| FR.A5 | Delay Offset | Slider -500ms hingga +500ms (default +150ms) untuk kompensasi DFPlayer |
| FR.A6 | Bluetooth Sync | Hubungkan ke ESP32 via BLE NimBLE |
| FR.A7 | Data Chunking | Pemecahan payload 512 bytes per chunk untuk kestabilan BLE |
| FR.A8 | Factory Reset | Kirim perintah reset ke ESP32 |
| FR.A9 | Premium Branding | Custom Launcher Icon & Animated Splash Screen (3 detik) |
| FR.A10| Cloud OTA Update | Download resource (JSON/MP3) dari Supabase dengan sistem **Hard-Gate** (wajib terkoneksi BLE untuk baca/tulis versi alat aktual). |

## Struktur Folder

```
lib/
├── main.dart                    # Entry point app
├── models/
│   ├── deret.dart               # Model data deret (slot, kata, timestamp)
│   └── word_entry.dart          # Model kata dengan timestamp
├── providers/
│   ├── ble_provider.dart        # Manajemen koneksi BLE (scan, connect, write)
│   └── workspace_provider.dart  # Manajemen state workspace & offset
├── screens/
│   ├── home_screen.dart         # Menu utama workspace + warning banner
│   ├── deret_editor_screen.dart  # Editor kata + waveform + auto-detect
│   ├── ble_sync_screen.dart      # Sinkronisasi Bluetooth + Factory Reset
│   ├── settings_screen.dart      # Pengaturan delay offset
│   └── services/
│       └── spike_detector.dart      # Algoritma deteksi spike dari waveform
├── assets/
│   └── icon/                        # Aset ikon & logo aplikasi (icon.png)
└── pubspec.yaml                     # Dependensi, aset, & icon generation config
```

## Format Data JSON

### Format Satu Deret (Single Deret)

```json
{
  "d": 1,
  "name": "Deret Satu",
  "v": [
    {"t": 13000, "w": "SABUN"},
    {"t": 20000, "w": "KUDA"},
    {"t": 28000, "w": "DINGIN"},
    {"t": 35000, "w": "BANYAK"},
    {"t": 42000, "w": "GULA"},
    {"t": 50000, "w": "PIPI"},
    {"t": 58000, "w": "BESAR"},
    {"t": 65000, "w": "ENAK"},
    {"t": 72000, "w": "LIDAH"},
    {"t": 80000, "w": "KEMBAR"}
  ]
}
```

### Format Bulk Payload (Semua Deret)

Ketika user klik "Sync All", aplikasi mengirim array JSON berisi semua deret yang sudah di-sync:

```json
[
  {
    "d": 1,
    "name": "Deret Satu",
    "v": [
      {"t": 13000, "w": "SABUN"},
      {"t": 20000, "w": "KUDA"},
      {"t": 28000, "w": "DINGIN"},
      {"t": 35000, "w": "BANYAK"},
      {"t": 42000, "w": "GULA"},
      {"t": 50000, "w": "PIPI"},
      {"t": 58000, "w": "BESAR"},
      {"t": 65000, "w": "ENAK"},
      {"t": 72000, "w": "LIDAH"},
      {"t": 80000, "w": "KEMBAR"},
      {"t": 88000, "w": "UMUR"},
      {"t": 95000, "w": "SALON"},
      {"t": 103000, "w": "TIKUS"},
      {"t": 110000, "w": "PANAH"},
      {"t": 118000, "w": "BECAK"},
      {"t": 125000, "w": "NASI"},
      {"t": 133000, "w": "ILMU"},
      {"t": 140000, "w": "KAMAR"},
      {"t": 148000, "w": "TELOR"},
      {"t": 155000, "w": "TEMPAT"}
    ]
  },
  {
    "d": 2,
    "name": "Deret Dua",
    "v": [
      {"t": 12000, "w": "WALI"},
      {"t": 19000, "w": "HAKIM"},
      {"t": 26000, "w": "PISTOL"},
      {"t": 33000, "w": "KORBAN"},
      {"t": 40000, "w": "DOSA"},
      {"t": 47000, "w": "BELI"},
      {"t": 54000, "w": "MEDAN"},
      {"t": 61000, "w": "KUMAN"},
      {"t": 68000, "w": "NAIK"},
      {"t": 75000, "w": "ADIK"},
      {"t": 82000, "w": "IBU"},
      {"t": 90000, "w": "TUGAS"},
      {"t": 97000, "w": "JARUM"},
      {"t": 105000, "w": "SALEP"},
      {"t": 112000, "w": "KABAR"},
      {"t": 119000, "w": "TOMAT"},
      {"t": 126000, "w": "KAPUR"},
      {"t": 133000, "w": "ANGIN"},
      {"t": 141000, "w": "ENCER"},
      {"t": 148000, "w": "MUSUH"}
    ]
  }
  // ... deret 3 hingga 10
]
```

### Keterangan Field

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `d` | Integer | Nomor slot deret (1-10) |
| `name` | String | Nama deret (tampil di display ESP32) |
| `v` | Array | Array kata |
| `v[].t` | Integer | Timestamp dalam milidetik (sudah + offset delay) |
| `v[].w` | String | Kata (maks 8 karakter, uppercase) |

### Contoh Perhitungan Offset

Jika user setting offset di app = +150ms (default), maka timestamp yang dikirim sudah dikalkulasi:

- Timestamp asli dari spike detection: `13000ms`
- Ditambah offset: `13000 + 150 = 13150ms`
- Hasil yang dikirim ke ESP32: `{"t": 13150, "w": "SABUN"}`

## Cara Menggunakan

### 1. Persiapan
```bash
cd flutter
flutter pub get
```

### 2. Build APK
```bash
flutter build apk
```

### 3. Alur Kerja

#### a. Buka App
- Tampilan Home dengan 10 slot deret
- Warning banner: "Gunakan file MP3 dari FOLDER 03 (bebas noise)"

#### b. Pilih Deret
- Klik slot deret untuk masuk editor
- Tambah/edit kata dengan timestamp

#### c. Pilih Audio
- Tekan tombol "Open" untuk pilih file MP3
- **PENTING:** Hanya gunakan MP3 dari Folder 03 (rekaman hening total)

#### d. Auto-Detect Spikes
- Tekan tombol "Auto-Detect Spikes"
- Algoritma mendeteksi lonjakan suara dari waveform
- **Mismatch Warning:** Jika jumlah spike ≠ jumlah kata, tampil peringatan orange

#### e. Edit Kata
- Setiap kata maksimal 8 karakter
- Timestamp dalam milidetik
- Bisa tambah/hapus kata manual

#### f. Simpan
- Tekan tombol check untuk simpan
- Data tersimpan di workspace (local)

#### g. Sinkronisasi ke ESP32
1. Buka menu Sync (icon Bluetooth)
2. Scan perangkat BLE
3. Pilih device dan masukkan PIN
4. Tekan "Sync All" untuk kirim semua data deret
5. Atau "Factory Reset" untuk reset ESP32

#### h. Cloud OTA (Hard-Gate Architecture)
Fitur ini menjamin akurasi versi dengan mewajibkan koneksi ke alat fisik:
1. **Bluetooth Lock:** Menu Update terkunci jika BLE tidak terhubung.
2. **Hardware Truth:** Aplikasi membaca versi dari NVS ESP32 via `@GET_VERSION`.
3. **Download:** Mengunduh aset (data.json & audio) sesuai selisih versi server.
4. **Commit:** Versi baru hanya ditulis ke NVS ESP32 (`@SET_VERSION`) setelah transfer lirik 10 deret sukses.

**Setup Supabase Bucket:**
1. Bucket public `lirik-assets` harus memiliki struktur:
   ```text
   lirik-assets/update/
         ├── version.txt               <-- Penanda rilis (contoh: 1.2.0)
         └── assets/
               ├── data.json            <-- Raw metadata lirik
               └── 001.mp3 - 010.mp3    <-- File audio
   ```
2. Setting endpoint di `lib/services/lyric_update_service.dart`.

## Bluetooth UUID

| UUID | Deskripsi |
|------|-----------|
| `4fafc201-1fb5-459e-8fcc-c5c9c331914b` | Lirik Service |
| `beb5483e-36e1-4688-b7f5-ea07361b26a8` | Karakteristik write |

## Format Perintah BLE

### Sync Data (Bulk Payload)

Data dikirim dalam format array JSON dengan delimiter `[EOF]`:

```json
[
  {"d":1,"name":"Deret Satu","v":[{"t":13000,"w":"SABUN"},...,
  {"d":2,"name":"Deret Dua","v":[{"t":12000,"w":"WALI"},...}]}[EOF]
```

### Chunking (Pemecahan Payload)

Karena BLE memiliki batasan MTU, payload dipecah menjadi chunk 512 bytes:

```
Chunk 1: [{"d":1,"name":"Deret Satu","v":[{"t":13000,"w":"SABUN"},{"t":20000,...
Chunk 2: ...}]}[EOF]
```

Setiap chunk dikirim secara berurutan dengan `withoutResponse: false` untuk memastikan data sampai.

### **Hardware Versioning:**
- `@GET_VERSION[EOF]` : Aplikasi meminta versi lirik dari ESP32.
- `@SET_VERSION:x.y.z[EOF]` : Aplikasi menyimpan versi `x.y.z` ke NVS ESP32.

**Factory Reset:**
```json
{"c": "reset"}[EOF]
```

ESP32 akan mereset semua data audio/lirik di LittleFS, namun tetap mempertahankan string versi di NVS.

## Dependencies

```yaml
dependencies:
  flutter_blue_plus: ^2.2.1      # Bluetooth LE
  audio_waveforms: ^2.0.2         # Waveform extraction
  file_picker: ^10.3.10           # File selection
  provider: ^6.1.5+1              # State management
  shared_preferences: ^2.5.5     # Local storage
  google_fonts: ^8.0.2            # Font (Outfit)
  http: ^1.2.2                    # Fetch API to Supabase
  permission_handler: ^11.3.1     # Perizinan Bluetooth & File
```

## Requirements

- Android minimum SDK 21
- Izin Bluetooth: BLUETOOTH_CONNECT, BLUETOOTH_SCAN
- Izin Location (Android < 12)

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bluetooth tidak bisa scan | Pastikan izin BLUETOOTH_CONNECT & BLUETOOTH_SCAN diberikan |
| Koneksi gagal | Pastikan ESP32 dalam mode advertising dan jarak dekat |
| Sync gagal/putus | Payload dipecah 512 bytes per chunk untuk kestabilan |
| Spike detection tidak akurat | Pastikan MP3 dari Folder 03 (bebas noise) |
| Kata tidak muncul di TFT | Kurangi offset delay di Settings (-500ms to +500ms) |
