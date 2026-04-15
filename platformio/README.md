# ESP32-S3 Lirik Player - Firmware (PlatformIO)

Firmware untuk perangkat ESP32-S3 yang menangani pemutaran audio (DFPlayer), tampilan lirik sinkron (TFT ST7735), dan sinkronisasi data via Bluetooth (BLE).

## Fitur Utama

- **BLE GATT Server**: Menerima data lirik JSON dari Flutter App via Bluetooth Low Energy.
- **BLE NOTIFY Feedback**: Mengirim status balik ke Flutter (`OK:10/10`, `ERR:JSON_PARSE`, dll) setelah sinkronisasi.
- **Data Persistence (LittleFS)**: Menyimpan data lirik ke memori internal Flash dengan partition scheme `min_spiffs.csv`. Seluruh sistem sekarang **100% berbasis LittleFS**, tidak lagi menggunakan data hardcoded memori flash.
- **Dynamic Loading**: Membaca lirik langsung dari struktur JSON di LittleFS ke RAM hanya saat diperlukan, menjaga konsumsi Memory Heap tetap hemat (> 200KB Free).
- **Decoupled BLE Processing**: Proses berat (JSON parsing + file write) dijalankan di main `loop()`, bukan di callback BLE, mencegah Stack Overflow pada task Bluetooth.
- **Memory Management**: Tracking `loadedWordCount` dan pembebasan memori (`free` + `delete[]`) saat ganti deret untuk mencegah memory leak.
- **Stable Button Inputs**: Memanfaatkan ESP32 `INPUT_PULLUP` dan active-LOW detection untuk menstabilkan masalah floating pin dan menghilangkan "ghost press" dari noise lingkungan.
- **Enhanced Serial Debug**: Logging detail dengan tag terstruktur untuk setiap subsistem.

## Konfigurasi Hardware (Wiring Pin)

Untuk menjaga stabilitas sistem ESP32-S3 (khususnya varian N16R8 dengan Octal PSRAM), beberapa pin telah dipindah dari konfigurasi default untuk menghindari bentrokan bus internal.

### 1. Display (TFT ST7735 SPI)
| Komponen | Pin | Deskripsi |
|----------|-----|-----------|
| **TFT CS** | 13 | Chip Select SPI LCD |
| **TFT RST**| 12 | Reset SPI LCD |
| **TFT DC** | 11 | Data/Command SPI LCD |
| **TFT MOSI**| 10 | MOSI SPI LCD |
| **TFT SCK** | 15 | Clock SPI LCD |
| **TFT MISO**| -1 | Tidak Digunakan |

### 2. Audio & RTC (Serial & I2C)
| Komponen | Pin | Deskripsi |
|----------|-----|-----------|
| **MP3 TX** | 16 | Ke pin RX DFPlayer Mini |
| **MP3 RX** | 7 | Dari pin TX DFPlayer Mini |
| **SDA (RTC)** | 39 | I2C Data DS3231 |
| **SCL (RTC)** | 40 | I2C Clock DS3231 |

### 3. Tombol Navigasi & Kontrol (Aktif LOW)
Semua tombol menggunakan konfigurasi `INPUT_PULLUP` internal.
| Komponen | Pin | Deskripsi |
|----------|-----|-----------|
| **Next** | 4 | Navigasi Maju |
| **Pause/OK**| 3 | Jeda atau Pilih Menu |
| **Home** | 1 | Kembali ke Menu Utama (Dev) |
| **Previous**| 2 | Navigasi Mundur (Dev) |
| **Vol Up** | 18 | Tambah Volume (Dev) |
| **Vol Down**| 9 | Kurangi Volume (Dev) |
| **Mode** | 6 | Ganti Mode Putar (Dev) |
| **MDokter** | 19 | Mode Dokter |
| **Power** | 46 | Tombol Power On/Off |

### 4. Power & Battery Management
| Komponen | Pin | Deskripsi |
|----------|-----|-----------|
| **BAT ADC** | 5 | Sensor Tegangan Baterai (Analog) |
| **CHRG Status**| 45 | Status Charging (Aktif LOW) |
| **STBY Status**| 48 | Baterai Full / Standby (Aktif LOW) |
| **TrigPower** | 21 | Trigger Output Power |

### 5. Trigger & Indikator Lainnya
| Komponen | Pin | Deskripsi |
|----------|-----|-----------|
| **TrigMic** | 8 | Trigger Output Mic |
| **TrigRlyDF** | 20 | Trigger Relay Modul Suara |
| **GPIO 14** | 14 | Input Serbaguna |
| **GPIO 17** | 17 | Output Serbaguna |
| **Pin LED** | 55 | Indikator LED Hardware |

## Struktur Program

| File | Deskripsi |
|------|-----------|
| `ESP32S3lirik2.ino` | Main entry, setup, loop, `listderet()` (LittleFS-first), memory management |
| `ble_server.ino` | BLE GATT Server, chunk reassembler, NOTIFY feedback, decoupled processing |
| `littlefs_handler.ino` | CRUD file JSON di internal Flash + dynamic word count tracking |
| `file.ino` | Menu deret di TFT, `displayDeretGeneric()` (1 fungsi generik untuk semua deret) |
| `oke.ino` | Handler tombol OK/Pause (non-blocking debounce) |
| `nextp.ino` | Handler tombol Next (non-blocking debounce) |
| `previouse.ino` | Handler tombol Previous (non-blocking debounce) |
| `volume.ino` | Kontrol volume DFPlayer |
| `mode.ino` | Mode putar (Kanan/Kiri/All) |
| `begin.ino` | Splash screen & inisialisasi awal |
| `readRTC.ino` | Pembacaan waktu DS3231 |
| `platformio.ini` | Konfigurasi project, dependencies, partition scheme |

## Alur Data (Sinkronisasi)

```
Flutter App                         ESP32-S3
    │                                   │
    ├── JSON Chunk (512 bytes) ──────►  │ BLE onWrite callback
    ├── JSON Chunk (512 bytes) ──────►  │ Buffer reassembly
    ├── ... + [EOF] ─────────────────►  │ EOF detected → flag set
    │                                   │
    │                                   ├── handleBLE() di loop()
    │                                   ├── Parse JSON (12KB buffer)
    │                                   ├── Write ke /lirik/deret_X.json
    │  ◄── NOTIFY "OK:10/10" ──────────┤ Status feedback
    │                                   │
    │   (Saat user pilih deret)         │
    │                                   ├── listderet()
    │                                   ├── Membaca dari LittleFS
    │                                   ├── Berhasil? → Load & Tampilkan TFT
    │                                   └── Kosong? → Render "DATA KOSONG"
```

> **INFO PENTING - CLOUD OTA SYSTEM:**  
> Meskipun fitur "Cloud-Based OTA (Supabase)" ditambahkan pada Flutter Mobile App, **Firmware ESP32-S3 sama sekali tidak perlu diubah ataupun terhubung ke koneksi internet/WiFi.**  
> Aplikasi Flutter berperan sebagai *AI Processor & Proxy*, dimana ia menangani proses unduhan internet, pemrosesan audio mentah, peringkasan payload JSON final, lalu mengirimkan hasilnya ke ESP32 murni via Bluetooth Offline. Arsitektur *loose coupling* ini menjaga sekuritas & reliabilitas alat medis dari bug jaringan eksternal.

## Panduan Development (Debug)

Monitor Serial Monitor pada baud rate **9600** untuk melihat log:

| Tag | Sumber | Informasi |
|-----|--------|-----------|
| `[LFS]` | `littlefs_handler.ino` | Inisialisasi, sisa memori Flash, listing file |
| `[LFS-READ]` | `littlefs_handler.ino` | Membaca file JSON dari Flash |
| `[LFS-WRITE]` | `littlefs_handler.ino` | Menulis file JSON + verifikasi ukuran |
| `[LFS-LOAD]` | `littlefs_handler.ino` | Parsing JSON ke struct `Word[]` |
| `[BLE]` | `ble_server.ino` | Koneksi/diskoneksi client |
| `[BLE-RX]` | `ble_server.ino` | Penerimaan chunk, ukuran buffer |
| `[BLE-LOOP]` | `ble_server.ino` | Proses payload di main loop |
| `[BLE-PARSE]` | `ble_server.ino` | Hasil parsing JSON (sukses/gagal) |
| `[BLE-PROC]` | `ble_server.ino` | Ekstraksi data per deret |
| `[BLE-SAVE]` | `ble_server.ino` | Status simpan ke LittleFS |
| `[BLE-NOTIFY]` | `ble_server.ino` | Feedback status ke Flutter |
| `[DERET]` | `ESP32S3lirik2.ino` | Load data LittleFS + perhitungan word count |
| `[MEM]` | `ESP32S3lirik2.ino` | Heap memory, pembersihan `strdup` + `delete[]` |
| `[SETUP]` | `ESP32S3lirik2.ino` | Status inisialisasi sistem |

## Optimasi yang Diterapkan

| # | Optimasi | Detail |
|---|---------|--------|
| 1 | **Fix Memory Leak** | `freeLoadedWords()` membebaskan setiap `strdup()`'d string sebelum `delete[]` |
| 2 | **Dynamic Word Count** | `loadedWordCount` menggantikan hardcoded `< 21` di `lirik()` |
| 3 | **Fix Bypass listderet** | `nextp.ino` tidak lagi langsung assign `words = wordsX` |
| 4 | **JSON Buffer 12KB** | `DynamicJsonDocument(12288)` cukup untuk bulk 10 deret |
| 5 | **Konsolidasi Display** | 10 fungsi `displayderet1-10` → 1 fungsi `displayDeretGeneric()` |
| 6 | **Partition Scheme** | `min_spiffs.csv` memperbesar ruang app + LittleFS |
| 7 | **LittleFS Only** | Penghapusan array data hardcoded `const char*` yang menghabiskan Flash secara sia-sia |
| 8 | **BLE JSON Fix** | Sinkronisasi perbaikan payload parsing dari key `"v"` (salah) menjadi `"w"` (dari Flutter) |
| 9 | **PSRAM Bypass** | RAM standar ESP32 >200KB terbukti mencukupi; menghindari delay/crash pada inisiasi bootloader akibat OctalSPI yang keliru |
| 10 | **Hardware Pull-Up** | Tombol navigasi tidak lagi "floating", menghindari screen rapid refresh/tampilan flickering |

## Cara Build & Upload

### Menggunakan PlatformIO (VS Code)

1. Buka folder `platformio` di VS Code.
2. Pastikan ekstensi **PlatformIO IDE** sudah terinstal.
3. Klik icon PlatformIO (semut) di sidebar.
4. Klik **Build** untuk mengecek error.
5. Klik **Upload** untuk memflash ke ESP32-S3.
6. Klik **Serial Monitor** (baud `9600`) untuk melihat debug log.

> **Catatan:** Error `Unable to handle compilation` di VS Code adalah normal untuk file `.ino`. Kompilasi hanya bisa dilakukan via PlatformIO, bukan langsung oleh clangd/IntelliSense.

## Factory Reset

Aplikasi Flutter dapat mengirim perintah `{"c":"reset"}[EOF]`. Saat diterima:
1. ESP32 menghapus semua file `/lirik/deret_*.json`.
2. Seluruh slot penyimpanan kembali dikosongkan secara dinamis.
3. ESP32 mengirim notifikasi `OK:RESET` ke Flutter.
