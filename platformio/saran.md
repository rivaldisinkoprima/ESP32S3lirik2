# 🚀 Blueprint Arsitektur & Optimasi ESP32-S3 (Lirik Sync V2)

Laporan ini mengkompilasi hasil pemindaian sistem secara menyeluruh dan menyajikan panduan *Advance Engineering* (Level Pakar). Tujuannya adalah untuk meng-upgrade proyek prototipe Anda menjadi perangkat siap-produksi (*Consumer-Grade Medical Device*) dengan performa, stabilitas, dan efisiensi daya maksimal.

---

## 🎨 1. Optimalisasi Rendering Layar (TFT UI Overhaul)

### A. Hilangkan Fungsi `drawPixel` untuk Aset Besar
- **Masalah:** Fungsi menu UI utama memuat gambar 128x156 *pixel by pixel* menggunakan kalang (loop) `tft.drawPixel`. Ini memaksa ESP32 mengeksekusi nyaris 20.000 transaksi SPI individu, mengakibatkan layar menggambar sangat lambat dengan respons usapan yang tertinggal.
- **Saran:** Ganti logika *loop* manual ini dengan blok *Direct Memory Access* (DMA). Gunakan fungsi dari library grafis seperti `tft.drawRGBBitmap()` atau `tft.pushImage()`. Ini akan melukis menu secara instan tanpa membebani sistem.

### B. Mulus Tanpa Berkedip dengan Teknologi Buffering (TFT_eSprite)
- **Masalah:** Antarmuka layar sering berkedip (*Flickering*) atau terlihat terhapus garis-demi-garis (*Screen Tearing*) karena penggunaan `tft.fillScreen(ST77XX_BLACK)` yang terus menerus saat berganti menu.
- **Saran:** Maksimalkan PSRAM 8MB milik ESP32-S3! Gunakan kanvas memori RAM (disebut Sprite). Gambarlah menu, teks, letak ikon di dalam ruangan *"imajiner"* di RAM terlebih dahulu. Setelah bingkai layar tergambar 100% sempurna di RAM (hanya butuh 0.001 detik), *semprotkan* (Push) bingkai utuh tersebut ke layar TFT. Animasi ganti menu Anda akan semulus Smartwatch kelas atas.

---

## 🧠 2. Keamanan Multi-Core & Keandalan RTOS

### C. Pemisahan Total Layar Antar Prosesor (Decoupled UI Architecture)
- **Masalah:** Sangat haram hukumnya menggambar UI langsung dari dua core yang berbeda (Core 0 BLE dan Core 1 Loop Utama) karena bisa mengunci jalur SPI dan memicu *Watchdog Timeout Crash*. 
- **Saran:** Core 0 (BLE) sama sekali tidak boleh memanggil fungsi *TFT*. Sebagai gantinya, Core 0 cukup melempar pesan persentase ke dalam "Kotak Surat" (*FreeRTOS Queue*). Lalu, mesin Layar di Core 1 akan membaca angka di kotak surat tersebut dan menggambar progress bar-nya dengan tertata rapi.

### D. Tinggalkan "Angka Gaib" dengan Mesin State (FSM - Finite State Machine)
- **Masalah:** Navigasi aplikasi saat ini sangat rapuh karena mengandalkan tebakan variabel seperti `if (posisi == 1)` atau `if (posisi == 5)`. Sangat mudah terjadi *bug* tumpang-tindih menu ke depannya.
- **Saran:** Gunakan **Enumeration (Enum)** dan `switch-case`. Definisikan mode secara lugas:
  ```cpp
  enum AppState { MENU_UTAMA, SCREENING_AUDIO, SINKRONISASI, MANAJEMEN_FILE };
  ```
  Alur logika aplikasi akan menjadi elegan, transisi layar akurat, dan sangat mudah untuk dirawat oleh developer.

---

## 💾 3. Infrastruktur File dan Efisiensi Data

### E. Integrasi *Atomic File Write* (Anti-Korupsi Data LittleFS)
- **Masalah:** Saat sinkronisasi JSON raksasa "Deret 10" dari BLE, jika tegangan listrik/baterai mati di tengah-tengah proses *save*, file `deret_10.json` akan terpotong (korup). Saat alat di-*restart*, parser JSON akan gagal dan alat akan nge-hang total.
- **Saran:** Gunakan teknik *Atomic Write*. ESP32 harus menulis JSON terbaru ke nama samaran dulu (Misal: `deret_10_tmp.json`). Setelah semua tertulis sukses dan tervalidasi strukturnya, ganti nama (*rename*) file tersebut menjadi file paten. Ini menjamin alat kebal terhadap mati-listrik ekstrem.

### F. Manajemen Memori Eksternal (PSRAM Allocator)
- **Masalah:** Objek JSON dengan puluhan lirik menghabiskan *Internal SRAM* yang sangat terbatas, memicu *Memory Leak*.
- **Saran:** Karena ESP32-S3 Anda seri N16R8, pastikan array *String* atau dokumen *ArduinoJson* dipaksa menggunakan `ps_malloc()` pengalokasi kustom. Biarkan beban berat ditanggung oleh RAM Eksternal yang luas, menjaga area bernapas Core.

---

## 🎛️ 4. Pembacaan Perangkat Keras & Baterai Pintar

### G. Ekstraksi Daya Super Hemat (Advanced Power Management)
- **Masalah:** Layar TFT dan prosesor yang dibiarkan hidup 100% saat alat sedang tidak memutar lagu akan menghisap daya baterai Litium dalam hitungan jam.
- **Saran:** Terapkan PWM pada pin LED layar untuk meredupkan *Backlight* hingga 20% apabila tidak disentuh selama 15 detik. Jika dianggurkan selama 5 menit, tidurkan seluruh chip ESP32 ke dalam mode **Deep Sleep**. Arus listrik akan anjlok menjadi hanya skala mikroAmpere (µA), dan akan otomatis bangun (*Wake-up via EXT0*) kembali segar saat tombol Home ditekan.

### H. Filter Pelembut Tegangan Baterai (EMA ADC Filter)
- **Masalah:** Modul Wi-Fi/BLE memancarkan *noise* magnetik, menyebabkan tegangan di *ADC Pin ESP32* bergetar hebat. Ini membuat persentase baterai di layar bisa menari-nari melompat angkanya.
- **Saran:** Tanamkan algoritma metematis **Exponential Moving Average (EMA)**. Nilai baterai detik ini dihitung dengan mencari titik rata-ratanya terhadap pembacaan historis detik-detik sebelumnya. Hasilnya, baterai Anda akan perlahan-lahan menyusut turun angka demi angka dengan konstan bak di *Smartphone*.

---

## 📞 5. Komunikasi Jaringan & Masa Depan

### I. Tinggalkan Logika Komunikasi DFPlayer yang Lamban
- **Masalah:** Melakukan interrogasi Status ke DFPlayer secara terus-menerus via jalur UART/Serial (`myDFPlayer.readState()`) merupakan leher botol yang besar dan bisa menyebabkan lirik kurang selaras dengan ucapan.
- **Saran Jangka Pendek:** Berhenti bertanya via algoritma Serial. Cukup hubungkan pin `BUSY` milik DFPlayer langsung ke pin masuk digital ESP32 (Hanya dicek via `digitalRead`).
- **Saran Jangka Panjang (Roadmap):** Pensiunkan modul DFPlayer. Gunakan chip bawaan ESP32 untuk mendekode audio berekstensi MP3 secara mandiri melalui antar-jalur **I2S Decoder (Misal: Modul Max98357A)**. Sinkronisasi waktu (*timer*) lirik terhadap dentis suara akan selaras mutlak dan presisi tingkat tinggi.

### J. Modul Antrean Tombol Fisik (FreeRTOS Hardware Queueing)
- **Masalah:** Membaca tombol melalui kalang `loop()` menyebabkan *lag*, serta pantulan listrik tombol (*bouncing*) sering diartikan sebagai "Double-Click".
- **Saran:** Berikan penugasan tombol murni ke pangkat **Interrupts (ISR)**. Layar yang membeku (*Ngelag*) sekalipun tetap mencatat setiap sentuhan pengguna dengan ketepatan per-milidetik, mengirim surat "Diklik" dan menampungnya melalui *Queue Buffer*. Mesin akan terasa amat responsif dan anti-telat.

### K. Pembaruan Gaib Tanpa Kabel USB (WiFi OTA Updates)
- **Masalah:** Saat casing produk medis sudah disegel baut rapat ke klien, perbaikan *bug-software* menuntut penyolderan ulang alat atau membongkar USB pelik.
- **Saran:** Sandi (*Compile*) kapabilitas **ArduinoOTA** ke perangkat. Sisipkan mode *Maintenance*. Saat klien memposisikan pemicu rahasia, perangkat membroadcast Wi-Fi Hotspot. Anda sebagai insinyur tinggal melempar file perbaikan kode `.bin` versi terbaru secara nirkabel lewat udara, menyelesaikan bongkar-memori seketika.

---
*Laporan Audit Otomasi Generasi Mutakhir | Lirik Sync V2 & Antigravity Systems*