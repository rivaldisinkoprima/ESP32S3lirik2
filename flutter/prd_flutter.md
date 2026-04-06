# Product Requirements Document (PRD) - Aplikasi Flutter
## Lirik Player V2 - Sync & Control Mobile App

**Versi:** 1.2
**Target Platform:** Android (Aplikasi Utama)
**Bahasa/Framework:** Dart (Flutter)
**Lokasi Proyek:** `flutter/`

---

### 1. Ringkasan Sistem Aplikasi
Aplikasi ini adalah jembatan *Wireless* yang bertugas merekam dan meracik lirik/kata beserta *timestamp*-nya berpatokan pada *waveform* file audio MP3 (Pemeriksaan Telinga/Audiometri). Aplikasi lalu mengemas seluruh data menjadi file JSON terenkapsulasi dan mentransmisikannya ke perangkat ESP32 via Bluetooth NimBLE.

### 2. Kebutuhan Fungsional (Functional Requirements)

- **FR.A1 - Manajemen Workspace (Dinamis):** Aplikasi memungkinkan pemetaan data berlapis. Admin bisa me-load slot "Deret 1" hingga "Deret X" dan file-file ini tersimpan sebagai *draft* (Workspace) sebelum diupload secara massa.
- **FR.A2 - Audio Spike Detection (Kecerdasan Inti):** 
  - Admin membuka MP3 di aplikasi.
  - Terdapat mekanisme pemindai *Waveform/Keheningan* yang mendeteksi lonjakan suara (*Spikes/Audio Envelopes*).
  - Jika ditemui jumlah lonjakan volume berbeda dengan jumlah teks kata yang diketik, muncul peringatan *Mismatch Warning*.
- **FR.A3 - Validasi Karakter Teks:** Aplikasi memberi batas ketat: Setiap kata tidak boleh lebih dari **8 karakter** saat diketik agar pas di muat OLED/TFT kecil.
- **FR.A4 - [SOP Audio Bebas Noise] Warning UI:** Di halaman unggah MP3, aplikasi selalu menampilkan peringatan keras (Pop-up/Banner): *"PERINGATAN: Harus memakai file MP3 dari FOLDER 03 (Hening total tanpa noise di kiri-kanan) untuk deteksi gelombang!"*.
- **FR.A5 - Hardware Delay Offset (Kompensasi Jeda Fisik):** Menyediakan kontrol *slider* global di pengaturan (misal: `-500ms` hingga `+500ms`, default `+150ms`). Jeda ini akan secara matematis ditambahkan ke serpihan waktu JSON terakhir untuk menutupi kelambatan modul *hardware* SD Card DFPlayer.
- **FR.A6 - Transmisi Sinkronisasi Bluetooth (Batch):** Saat tombol *"Sync All"* ditekan, aplikasi mencari MAC Address perangkat/meminta masukan **PIN Statis Bluetooth**.
- **FR.A7 - Data Chunking Algorithm (Pemecah Bytes):** Flutter tidak boleh melempar 5KB payload JSON dideretkan lurus, melainkan harus dipotong *buffer substring* 512 bytes tiap putaran, disempilkan ke Karakteristik BLE agar koneksi radionya tidak lemas/putus.
- **FR.A8 - Kirim Sinyal Factory Reset:** UI menyediakan tuas darurat "Kembalikan Perangkat ke Default" yang mengirim string `{ "c": "reset" }` menendang modul ESP32 ke format pabrikan aslinya.
- **FR.A9 - Premium Branding & UX:** Implementasi ikon aplikasi khusus dan layar splash animasi (Fade/Scale) berdurasi 3 detik untuk meningkatkan tampilan premium aplikasi.

### 3. Struktur Blueprint Komunikasi JSON

```json
{
  "d": 11,           // Nomor Deret / Slot
  "name": "Deret Sebelas", // Nama/Judul jika akan dirender di Layar ESP32
  "v": [
    {"t": 13150, "w": "SABUN"}, // Waktu T sudah dikurangi/ditambah Offset Delay
    {"t": 20150, "w": "KUDA"}
  ]
}
```

### 4. Batasan & Syarat Spesial
- **Izin Bluetooth (Permissions):** Memerlukan akses *BLUETOOTH_CONNECT*, *BLUETOOTH_SCAN*, letak *Location/GPS (di Android bawah V12)*.
- **Prosedur Unggah:** Proses sinkronisasi gelombang suara MP3 di HP akan murni terjadi di *Local Logic (RAM HP Android)* tanpa *Upload* ke server luar/Internet.
