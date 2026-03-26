# Audio Processing Tools Untuk Audio Screening Lirik Player

Kumpulan script Python ini berfungsi untuk menstandarisasi file **MP3**. Program ini memastikan letak kata diucapkan memiliki jarak detik yang **100% konsisten (otomatis)** dan membuat Noise Latar (Room Tone) yang stabil. File output ini yang nantinya wajib disalin ke dalam micro SD Card di DFPlayer Mini ESP32-S3 Anda.

### 🛠️ Prasyarat (Harus Diinstal Sekali Saja)

Script Python ini menggunakan library \`pydub\` yang membutuhkan **FFmpeg** untuk membaca file MP3. FFmpeg bukan modul Python (pip), melainkan software sistem (C/C++). 

**1. Cara Install FFmpeg di Windows via Scoop (Sangat Disarankan):**
Buka PowerShell, lalu ketik berurutan:
\`\`\`bash
# Jika belum punya Scoop, install dengan perintah (kopi-paste 2 baris ini):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Jika Scoop sudah terpasang, cukup jalankan:
scoop install ffmpeg
\`\`\`

**2. Instalasi Modul Python:**
Dalam folder \`audio/\` ini, jalankan instalasi *dependencies*-nya satu kali saja:
\`\`\`bash
pip install -r requirements.txt
\`\`\`
*(Catatan: Paket \`audioop-lts\` ditambahkan agar script tidak error bagi Anda yang menggunakan Python versi 3.13 ke atas).*

---

### 🚀 Alur Kerja Program

**Tahap 1: Generate Stereo (L/R)**
Jika Anda hanya memiliki rekaman `03/` (Kanan-Kiri bunyi) dan ingin membuat tes kuping sebelah (Kiri Noise, Kanan Suara, dan sebaliknya), jalankan:
\`\`\`bash
python generate_stereo.py
\`\`\`
*(Hasil akhir akan diletakkan di dalam folder `01/` dan `02/` terpisah)*

**Tahap 2: Standarisasi Audio (Splicing & Interval Adjustment)**
Setelah ketiga folder (`01/`, `02/`, `03/`) dirasa utuh, rapikan semua jeda (interval) setiap file agar terpotong konsisten setiap 5 Detik. Jalankan:
\`\`\`bash
python standarisasi_audio.py
\`\`\`
*(Otomatis menormalisasi volume, taktik Anti-Kata-Terpotong, dan mendaur-ulang "Noise" bawaan mp3 menjadi sela/lem antar kata)*

**Tahap 3: Selesai!**
File matang yang sudah jadi ada di dalam folder:
\`audio/output/01/\`
\`audio/output/02/\`
\`audio/output/03/\`

Salin dan tempel (Paste) folder-folder ini ke dalam SD Card modul suara Anda.

---

### 🐜 Mode Debugging
Jika file gagal terpotong / hasil dirasa aneh (suara kata hilang atu menyatu 50 detik), selalu jalankan program **Rontgen/Diagnosa** di bawah ini untuk melihat Timeline (X-Ray) rekaman Anda:
\`\`\`bash
python analisa_audio.py
\`\`\`
