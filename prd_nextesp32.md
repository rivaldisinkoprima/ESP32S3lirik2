# Product Requirements Document (PRD) - ESP32 Firmware
## Lirik Player V2 - Hardware & BLE Synchronization

**Versi:** 1.0
**Kategori:** Perangkat Keras / Embedded C++
**Lingkungan:** Arduino IDE / PlatformIO
**Lokasi Proyek:** `/ESP32S3lirik2/`

---

### 1. Ringkasan Kebutuhan Firmware
Perangkat keras (ESP32-S3) tidak lagi menyimpan database teks/judul lirik di dalam struktur *hardcode variabel memori RAM* bawaannya. File C++ `ESP32S3lirik2.ino` akan dikembangkan (*refactor*) menjadi pembaca dinamis yang mengekstrak informasi lirik yang tersimpan pada File System Internal Flash (`LittleFS / SPIFFS`). 

### 2. Kebutuhan Fungsional (Firmware Requirements)

#### 2.1. Memori Penyimpanan File Internal (LittleFS)
- **FR.E1 - Relokasi Hardcode:** Menghapus fungsi array `Word words[20]` konstan dan diganti menjadi struktur dinamis kosong.
- **FR.E2 - JSON File Reader:** Saat *User* memilih "Deret M", pembacaan sistem ESP32 membuka `/lirik/deret_M.json` via modul *ArduinoJSON*. Algoritma lalu mentransfer seluruh data *Timestamp* (Waktu) & *Word* (Kata) itu ke baris array struct sementaranya untuk dimainkan selaras fungsi timer `millis()`.
- **FR.E3 - Manajemen Folder Bawaan:** Jika ESP32 dinyalakan berstatus *"Factory Reset"* (file JSON kosong), maka ESP32 menyiapkan memori atau langsung me-load file konstan lama dari bank memorinya sebagai *Fallback*.

#### 2.2. Manajemen Tampilan Layar TFT (Dynamic Menu)
- **FR.E4 - Pembacaan Scanner Dinamis (`file.ino`):** Fungsi penggambaran layar tidak boleh distop di "10 Deret". Kode perlu mendeteksi ada berapa file `deret_X.json` di *LittleFS*, kemudian menyusunnya secara iteratif di opsi menu `TFT Menu` agar tampil deret ke 11, 12, dst.

#### 2.3. Sistem Penerimaan Transmisi Bluetooth (NimBLE)
- **FR.E5 - BLE GATT Server (PIN Protected):** Platform IO menggunakan library *NimBLE-Arduino*. Server dikunci dengan *Passkey/PIN Statis* (misal: 123456).
- **FR.E6 - Algoritma Penampung Chunking (Buffer):** Ketika Flutter melempar patahan pesan JSON raksasa berukuran lebih besar dari MTU, Karakteristik Bluetooth `write callback` di ESP32 tidak langsung mengeksekusi tulis ke file, melainkan menampungnya ke dalam string komposit (misal variabel `String blePayloadBuffer`).
- **FR.E7 - Eksekusi Payload:** Setelah ESP32 mendeteksi tanda pengakhiran (Contoh: menemukan string `[EOF]`), fungsi akan memanggil unit `ArduinoJSON`, memecah array Bulk Deret File tersebut, lalu menuliskannya ke dalam *LittleFS*.

### 3. Interaksi Ekosistem Modul Audio (DFPlayer)
- Proses file MP3 tidak tersentuh sistem *Bluetooth*. MP3 tetap disimpan manual oleh Admin ke SD Card DFPlayer.
- Saat ESP32 mendapatkan parameter Offset waktu dari JSON perangkat Android, sistem lirik akan membaca waktu yang sudah kompensasi (*Delayed loading kompensator*), jadi fungsi *trigger* ke Playback Hardware akan tetap utuh tanpa modifikasi delay lebih jauh.

### 4. Rencana Kerja (Eksekusi Tahap Bawah)

**Fase A: Sistem Sinkronisasi File (Offline)**
1. Konversi baris struct C++ ke format pembacaan LittleFS/SPIFFS menggunakan library `FS.h` dan `LittleFS.h`.
2. Menyisipkan parsing library `ArduinoJson.h` untuk merebut Value Data (Kata Dinamis).

**Fase B: Transistor Komunikasi Data**
1. Implementasi modul NimBLE GATT dengan Profile `LirikS3Server`.
2. *Setup handler* PIN Authentication.
3. Sinkronisasi *Chunk Reassembler* Buffer dan konfirmasi `[FINISH/SUCCESS]`.
