# Testing Guide - ESP32 BLE Sync

## Overview

Setelah firmware di-upload ke ESP32, lakukan testing dengan Flutter App untuk memastikan sinkronisasi data berfungsi.

## Persiapan

### 1. Hardware
- ESP32-S3 dengan firmware terbaru
- USB Power untuk ESP32
- HP Android dengan Flutter App terinstall

### 2. Flutter App
- Install APK di HP Android
- Buka app dan navigasi ke menu Sync (icon Bluetooth)

---

## Langkah Testing

### Test 1: Koneksi BLE

1. **Di ESP32:**
   - Nyalakan ESP32
   - Buka Serial Monitor (9600 baud) untuk melihat log
   - Pastikan ada pesan: `[BLE] Server started`

2. **Di Flutter App:**
   - Buka menu Sync
   - Tekan tombol scan (FAB/ikon search)
   - Cari device "Lirik S3"
   - Klik Connect
   - Masukkan PIN: `123456`

3. **Verifikasi:**
   - Di Serial Monitor ESP32: `[BLE] Client connected`
   - Di Flutter App: Status berubah jadi "Device Connected"

---

### Test 2: Sinkronisasi Data

1. **Di Flutter App:**
   - Buat data deret (bisa edit manual atau auto-detect)
   - Pastikan ada kata di deret 1
   - Tekan tombol "Sync All"

2. **Verifikasi:**
   - Di Serial Monitor ESP32:
     ```
     [BLE] Received: XXX bytes
     [BLE] Processing payload...
     [BLE] Bulk payload: X derets
     [BLE] Processing Deret 1
     [BLE] Would save Deret 1 (Deret Satu) to LittleFS
     ```

---

### Test 3: Factory Reset

1. **Di Flutter App:**
   - Pastikan sudah terhubung ke ESP32
   - Tekan tombol "Factory Reset"

2. **Verifikasi:**
   - Di Serial Monitor ESP32:
     ```
     [BLE] Received: XX bytes
     [BLE] Factory Reset command received!
     [BLE] Performing factory reset...
     [BLE] Factory reset complete
     ```

---

### Test 4: Lirik Display

1. **Di ESP32:**
   - Pilih deret yang sudah di-sync (belum works untuk sementara)
   - Putar musik DFPlayer
   - Lirik seharusnya tampil di TFT

**Catatan:** Untuk sementara, lirik masih menggunakan data hardcoded. Fitur LittleFS akan aktif setelah LittleFS di-init dengan benar.

---

## Expected Output Serial Monitor

```
[BLE] Initializing ESP32 BLE...
[BLE] Server started - Waiting for connections...
[BLE] Device Name: Lirik S3
[BLE] Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
[BLE] Client connected
[BLE] Received: 256 bytes
[BLE] Processing payload...
[BLE] Bulk payload: 2 derets
[BLE] Processing Deret 1
[BLE] Processing Deret 2
```

---

## Troubleshooting

| Masalah | Cause | Solusi |
|---------|-------|--------|
| Device tidak muncul di scan | ESP32 belum di-upload firmware BLE | Upload firmware terbaru |
| Koneksi gagal | PIN salah | Gunakan PIN 123456 |
| Data tidak tersimpan | LittleFS belum ready | Cek Serial Monitor untuk error |
| Lirik tidak muncul | Masih pake hardcoded | Sementara gunakan mode biasa |

---

## Format Data JSON

### Bulk Payload
```json
[
  {"d":1,"name":"Deret 1","v":[{"t":13000,"w":"SABUN"},...]},
  {"d":2,"name":"Deret 2","v":[{"t":12000,"w":"WALI"},...]}
][EOF]
```

### Factory Reset
```json
{"c": "reset"}[EOF]
```

---

## Catatan

- BLE UUID Service: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- BLE UUID Characteristic: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Delimiter: `[EOF]`
- Max payload per chunk: ~512 bytes (handled by Flutter)
