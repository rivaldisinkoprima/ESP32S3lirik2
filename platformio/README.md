# ESP32-S3 Lirik Player - Firmware (PlatformIO)

Firmware untuk perangkat ESP32-S3 yang menangani pemutaran audio (DFPlayer), tampilan lirik sinkron (TFT ST7735), dan sinkronisasi data via Bluetooth (BLE). Mendukung jumlah deret dinamis tanpa batas hardcode dengan sistem manajemen memori PSRAM adaptif.

## Fitur Utama

- **BLE GATT Server**: Menerima data lirik JSON dari Flutter App via Bluetooth Low Energy.
- **BLE NOTIFY Feedback**: Mengirim status balik ke Flutter (`OK:10/10`, `ERR:JSON_PARSE`, `ERR:MEM_FULL`, dll) setelah sinkronisasi.
- **Data Persistence (LittleFS)**: Menyimpan data lirik ke memori internal Flash dengan partition scheme `min_spiffs.csv`. Seluruh sistem sekarang **100% berbasis LittleFS**, tidak lagi menggunakan data hardcoded memori flash.
- **Dynamic Loading**: Membaca lirik langsung dari struktur JSON di LittleFS ke RAM hanya saat diperlukan, menjaga konsumsi Memory Heap tetap hemat (> 200KB Free).
- **Dynamic Deret Slots**: Jumlah deret tidak lagi dibatasi 10. Sistem otomatis mendeteksi jumlah file `deret_X.json` di LittleFS dan menyesuaikan menu TFT, navigasi screening, dan progress bar secara dinamis.
- **PSRAM Safety Gate (90%)**: Sebelum menyimpan data baru, ESP32 mengecek ketersediaan PSRAM dan Flash. Jika penggunaan melebihi 90%, request ditolak dengan kode `ERR:MEM_FULL` untuk mencegah crash.
- **Adaptive Memory Diagnostics**: Saat boot, ESP32 membaca `ESP.getPsramSize()` untuk menghitung threshold secara adaptif. Jika chip di-upgrade dari 8MB ke 16MB PSRAM, threshold otomatis menyesuaikan tanpa perubahan kode.
- **DMA Bitmap Rendering**: Aset gambar besar (logo, menu background) di-render menggunakan `tft.drawRGBBitmap()` (Direct Memory Access) menggantikan loop `drawPixel` yang lambat.
- **GFXcanvas16 Buffering**: Menu file dan daftar deret di-render ke canvas RAM terlebih dahulu, lalu di-push ke layar dalam satu operasi untuk menghilangkan flickering total.
- **Decoupled BLE Processing**: Proses berat (JSON parsing + file write) dijalankan di main `loop()`, bukan di callback BLE, mencegah Stack Overflow pada task Bluetooth.
- **Memory Management**: Tracking `loadedWordCount` dan pembebasan memori (`free` + `delete[]`) saat ganti deret untuk mencegah memory leak.
- **Stable Button Inputs**: Memanfaatkan ESP32 `INPUT_PULLUP` dan active-LOW detection untuk menstabilkan masalah floating pin dan menghilangkan "ghost press" dari noise lingkungan.
- **Enhanced Serial Debug**: Logging detail dengan tag terstruktur untuk setiap subsistem.

## Persyaratan Hardware

| Komponen | Pin (ESP32-S3) | Deskripsi |
|----------|----------------|-----------|
| **TFT CS** | 13 | Chip Select SPI |
| **TFT RST**| 12 | Reset SPI |
| **TFT DC** | 11 | Data/Command SPI |
| **TFT MOSI**| 10 | MOSI SPI |
| **TFT SCK** | 15 | Clock SPI |
| **MP3 TX** | 36 | Software Serial ke DFPlayer |
| **MP3 RX** | 35 | Software Serial ke DFPlayer |
| **Button Next** | 4 | Navigasi |
| **Button Pause**| 3 | OK / Pause |
| **SDA (RTC)** | 37 | I2C untuk DS3231 |
| **SCL (RTC)** | 38 | I2C untuk DS3231 |

## Struktur Program

| File | Deskripsi |
|------|-----------|
| `ESP32S3lirik2.ino` | Main entry, setup, loop, `listderet()`, memory management, `checkMemorySafety()`, PSRAM diagnostics |
| `ble_server.ino` | BLE GATT Server, chunk reassembler, NOTIFY feedback, Safety Gate, decoupled processing |
| `littlefs_handler.ino` | CRUD file JSON di internal Flash + dynamic word count tracking + `getDeretCount()` |
| `file.ino` | Menu deret dinamis di TFT (GFXcanvas16 buffered), `displayDeretGeneric()` |
| `home.ino` | Render menu utama dengan `drawRGBBitmap()` (DMA, tanpa flicker) |
| `begin.ino` | Splash screen dengan DMA bitmap rendering |
| `oke.ino` | Handler tombol OK/Pause (non-blocking debounce) |
| `nextp.ino` | Handler tombol Next (non-blocking debounce) |
| `previouse.ino` | Handler tombol Previous (non-blocking debounce) |
| `volume.ino` | Kontrol volume DFPlayer |
| `mode.ino` | Mode putar (Kanan/Kiri/All) |
| `readRTC.ino` | Pembacaan waktu DS3231 |
| `plan_dynamic_slots.md` | Blueprint arsitektur sistem deret dinamis & PSRAM Safety Gate |
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
| `[MEM-CHECK]` | `ESP32S3lirik2.ino` | Safety Gate: cek PSRAM & Flash sebelum simpan |
| `[DERET]` | `ESP32S3lirik2.ino` | Load data LittleFS + perhitungan word count |
| `[MEM]` | `ESP32S3lirik2.ino` | Heap memory, pembersihan `strdup` + `delete[]` |
| `[SETUP]` | `ESP32S3lirik2.ino` | Status inisialisasi sistem + PSRAM/Flash diagnostics |

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
| 11 | **DMA Bitmap Rendering** | `drawPixel` loop manual (~20.000 transaksi SPI) diganti `tft.drawRGBBitmap()` untuk rendering instan |
| 12 | **GFXcanvas16 Buffering** | Menu file/deret di-render ke canvas RAM lalu di-push ke layar dalam 1 operasi, menghilangkan flickering |
| 13 | **Anti-Tearing Home** | `tft.fillScreen(BLACK)` sebelum draw menu dihapus agar tidak ada sapuan hitam saat refresh |
| 14 | **Dynamic Deret Slots** | Batasan hardcode 10 deret dihapus; jumlah deret mengikuti file LittleFS aktual |
| 15 | **PSRAM Safety Gate** | `checkMemorySafety()` mencegah penulisan jika PSRAM >90% atau Flash <50KB tersisa |
| 16 | **Adaptive Memory Threshold** | `ESP.getPsramSize()` dibaca saat boot; threshold 10% dihitung otomatis (skalabel 8MB/16MB/32MB) |
| 17 | **Dynamic Progress Bar** | Progress bar sync membagi `slot/total` (bukan `slot/10`), akurat untuk jumlah deret berapapun |

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
