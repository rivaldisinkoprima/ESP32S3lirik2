# 📡 Feature Spec: Cloud-Triggered Hybrid Update System (Version-Gate Strategy)

**Project:** Lirik Sync V2  
**Scope:** Update Otomatis Aset (Audio & Raw JSON) menggunakan Supabase Storage.
**Status:** IMPLEMENTED ✅
**Trigger Mode:** Manual Trigger (Check Update & Download by User).  
**Last Updated:** 2026-04-08

---

## 1. System Architecture: The "Threshold" Strategy

Untuk efisiensi maksimal, sistem menggunakan gerbang pengecekan (`version.txt`) sebelum melakukan pengunduhan aset besar.

```
[ SERVER ]
    ├── version.txt       <-- Smallest file (contains: "1.2.0")
    └── assets/
         ├── data.json    <-- Raw Lyrics (Teks Mentah)
         └── sync_3.mp3   <-- Audio Source untuk Processing

[ FLUTTER APP ]
    Step 1: Download version.txt (miliseconds)
    Step 2: Compare local_version vs server_version
    Step 3: If version differs, enable "DOWNLOAD & PROCESS" button
    Step 4: Process Audio + JSON -> Final JSON with Timestamps
    Step 5: Bluetooth Send to ESP32
```

---

## 2. Server-Side Setup

### 2.1 The Version Gate (Supabase)
Sistem ini menggunakan Supabase Storage (`lirik-assets` bucket) sebagai CDN Cloud.
URL untuk file version:  
`https://[PROJECT_ID].supabase.co/storage/v1/object/public/lirik-assets/version.txt`
Isi file (Plain Text): `1.2.5`

### 2.2 Asset Directory
Tempatkan file mentah ter-update di bucket Supabase yang sama:
`https://[PROJECT_ID].supabase.co/storage/v1/object/public/lirik-assets/data.json`  
`https://[PROJECT_ID].supabase.co/storage/v1/object/public/lirik-assets/audio_deret_1.mp3`

---

## 3. Flutter Implementation Workflow

### PHASE 1: Detection (User Click "Check Update")
1. User menekan tombol **"Periksa Pembaruan"**.
2. Flutter melakukan `HTTP GET` ke `version.txt`.
3. **Logic:**
   ```dart
   if (version_server > version_lokal) {
      showDialog("Update Tersedia!", "Terdapat pembaruan versi ${version_server}. Unduh sekarang?");
      activateUpdateButton();
   } else {
      showToast("Anda sudah menggunakan versi terbaru.");
   }
   ```

### PHASE 2: Download & AI Processing (User Click "Update Now")
1. **Fetch Large Assets:** Flutter mendownload `data.json` dan file `.mp3` pendukung yang diperlukan.
2. **AI Syncing Engine:** Flutter memproses gelombang audio dan teks mentah tersebut untuk mendapatkan koordinat waktu (*timestamp*) yang presisi untuk setiap kata.
3. **Internal Storage:** JSON Hasil Olahan (Final JSON) disimpan sementara di HP.

### PHASE 3: Device Syncing (BLE Handover)
1. **Bluetooth Check:** User diminta menyambungkan alat ke alat ESP32.
2. **Transfer:** Flutter mengirimkan kepingan data JSON Final ke ESP32 melalui Bluetooth.
3. **ACK & Commit:** ESP32 membalas dengan `OK`. Saat itu juga, Flutter mengubah `local_version` menjadi versi terbaru (`1.2.5`).

---

## 4. Key Performance Indicators (KPI)

1. **Lightweight Check:** Pengecekan versi hanya memakan kuota < 1 KB.
2. **User Agency:** Tidak ada kuota user yang terpakai untuk file besar kecuali user setuju untuk klik tombol "Update".
3. **Firmware Compatibility:** ESP32 tidak perlu tahu soal internet atau versi cloud. Ia hanya menerima lirik final, sehingga kode ESP32 yang sekarang tidak perlu diubah lagi.

---

## 5. Security & Safety

- **Atomic Update:** Pastikan `local_version` di HP hanya diupdate SETELAH aplikasi Flutter selesai mengekstrak dan menyimpan data. 
- **User Permission:** Aplikasi menggunakan plugin `permission_handler` secara eksplisit, dan seluruh network request berjalan secara asinkron tanpa memblokir UI (`async`/`await`).

---

## 6. Architecture Map (Implemented)
- **`LyricUpdateProvider`:** State management untuk alur unduhan dan sinkronisasi.
- **`LyricUpdateService`:** Abstraksi layanan HTTP untuk menarik data dari API Supabase.
- **`CloudUpdateScreen`:** Antarmuka pengguna (UI) modern tempat pengguna menekan "Check Update" dengan indikasi proses dinamis.

---
*Document Type: System Architecture / Implementasi Telah Sukses*  
*Target: Release & Production* 🚀
