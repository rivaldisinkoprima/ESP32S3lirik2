# Dokumentasi Teknis ESP32-S3 Lirik Player

## 1. Gambaran Umum Proyek

Proyek ini adalah perangkat pemutar lagu dengan tampilan lirik (lyrics display) berbasis ESP32-S3. Perangkat ini dirancang untuk menampilkan lirik lagu secara sinkron dengan musik yang diputar melalui modul DFPlayer Mini.

### Fitur Utama:
- Pemutaran musik menggunakan DFPlayer Mini
- Tampilan lirik sinkron pada display TFT ST7735
- 10 deret (series) kata dengan total 200 kata
- Navigasi menu dengan tombol fisik
- Pengaturan waktu (RTC DS3231)
- Monitoring baterai dan status charging
- Mode putar: semua, kanan, atau kiri
- Kontrol volume
- Mode dokter (mic) untuk bicara

---

## 2. Spesifikasi Hardware

### 2.1 Komponen Utama

| Komponen | Spesifikasi |
|----------|-------------|
| Mikrokontroler | ESP32-S3 |
| Display | TFT ST7735 128x160 piksel |
| Audio Module | DFPlayer Mini |
| RTC | DS3231 |
| Battery | Li-ion dengan ADC monitoring |

### 2.2 Pin Configuration

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

### 2.3 Rangkaian Daya

```
- VCC: 3.3V (ESP32) & 5V (DFPlayer, TFT)
- Battery: 3.7V Li-ion
- Voltage Divider untuk ADC: Rasio 2.0
```

---

## 3. Arsitektur Software

### 3.1 Struktur Program

Program utama terdiri dari beberapa file `.ino` yang diinclude dalam satu sketch:

| File | Fungsi |
|------|--------|
| `ESP32S3lirik2.ino` | Main program, setup, loop, variabel global |
| `begin.ino` | Inisialisasi device, splash screen |
| `home.ino` | Kembali ke menu utama |
| `oke.ino` | Konfirmasi/OK button handler |
| `nextp.ino` | Tombol next handler |
| `previouse.ino` | Tombol previous handler |
| `volume.ino` | Kontrol volume |
| `mode.ino` | Mode putar & setting waktu |
| `Mic.ino` | Mode mikrofon dokter |
| `file.ino` | Menu file/deret |
| `tampiljam.ino` | Tampilan jam RTC |
| `readRTC.ino` | Pembacaan RTC |
| `autodetect_state_df.ino` | Deteksi status DFPlayer |
| `readButtonState.ino` | Pembacaan state tombol power |

### 3.2 Library yang Digunakan

```cpp
#include <Arduino.h>
#include <Wire.h>
#include "RTClib.h"
#include <SoftwareSerial.h>
#include <DFRobotDFPlayerMini.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <SPI.h>
#include <SD.h>
```

### 3.3 State Machine

Sistem menggunakan variabel `posisi` untuk menentukan state:

| Nilai | State | Deskripsi |
|-------|-------|-----------|
| 1 | Menu Utama | Tampilan menu dengan 3 opsi |
| 2 | Screening/Lirik | Mode putar dengan tampilan lirik |
| 3 | Atur Jam | Mode pengaturan waktu |
| 4 | Daftar File | Menu pemilihan deret |
| 5 | Detail Deret | Tampilan detail kata dalam deret |

### 3.4 Variabel Global Utama

```cpp
int posisi = 1;        // State machine
int pilihan = 1;       // Posisi cursor menu
int deret = 1;         // Deret yang dipilih (1-10)
int mode = 1;          // Mode putar (1=All, 2=Kiri, 3=Kanan)

boolean isPlaying;     // Status putar
int loud = 13;         // Volume (0-30)
int t_loud = 35;       // Tampilan volume

bool dokter_bicara = false;  // Mode dokter
```

---

## 4. Fitur & Implementasi

### 4.1 Manajemen Lirik Sinkron

Lirik disimpan dalam struct `Word` dengan format:

```cpp
struct Word {
  float time;          // Waktu muncul (dalam milidetik)
  const char* text;   // Teks yang ditampilkan
};
```

Terdapat 10 array `words1` hingga `words10` untuk setiap deret:

```cpp
Word words1[] = {
  {0,"DERET 1"},
  {13000,"1. SABUN"},
  {20000,"2. KUDA"},
  // ... hingga 20 kata per deret
};
```

**Mekanisme Sinkronisasi:**
1. Setiap deret memiliki timing spesifik (dalam milidetik)
2. Fungsi `lirik()` dipanggil saat music playing
3. `startCounter()` memulai timer
4. Setiap kata ditampilkan berdasarkan elapsed time

### 4.2 Sistem Menu

**Menu Utama (3 opsi):**
1. Screening (putar lirik)
2. File (daftar deret)
3. Atur Jam

Navigasi menggunakan `menu(pilihan)` yang menggambar rectangle highlight.

### 4.3 Kontrol DFPlayer

```cpp
// Pemutaran berdasarkan mode dan deret
if (mode==1) myDFPlayer.playFolder(1, deret);  // Folder 1: All
if (mode==2) myDFPlayer.playFolder(2, deret); // Folder 2: Kiri
if (mode==3) myDFPlayer.playFolder(3, deret); // Folder 3: Kanan
```

### 4.4 RTC (DS3231)

Pembacaan RTC dilakukan setiap 30 menit:

```cpp
if (millis() - lastRTC >= 30000) {
  readRTC();
}
```

Format waktu: 24 jam (HH:MM)

### 4.5 Battery Monitoring

Monitoring menggunakan ADC dengan konfigurasi:

```cpp
analogReadResolution(12);
analogSetAttenuation(ADC_11db);
```

Status charging dideteksi melalui pin `PIN_CHRG` dan `PIN_STBY`.

### 4.6 Kontrol Daya

Tombol power dengan long-press (2 detik) untuk shutdown:

```cpp
unsigned long minButtonLongPressDuration = 2000;
```

---

## 5. Data Kata per Deret

### Deret 1 (words1)
1. SABUN, 2. KUDA, 3. DINGIN, 4. BANYAK, 5. GULA, 6. PIPI, 7. BESAR, 8. ENAK, 9. LIDAH, 10. KEMBAR, 11. UMUR, 12. SALON, 13. TIKUS, 14. PANAH, 15. BECAK, 16. NASI, 17. ILMU, 18. KAMAR, 19. TELOR, 20. TEMPAT

### Deret 2 (words2)
1. WALI, 2. HAKIM, 3. PISTOL, 4. KORBAN, 5. DOSA, 6. BELI, 7. MEDAN, 8. KUMAN, 9. NAIK, 10. ADIK, 11. IBU, 12. TUGAS, 13. JARUM, 14. SALEP, 15. KABAR, 16. TOMAT, 17. KAPUR, 18. ANGIN, 19. ENCER, 20. MUSUH

### Deret 3 (words3)
1. TULI, 2. PADI, 3. KELAS, 4. RAMBUT, 5. NYAMUK, 6. GARAM, 7. BIDAN, 8. BUMI, 9. KERAS, 10. NIKAH, 11. OBAT, 12. KARCIS, 13. DALANG, 14. MESIN, 15. KUPON, 16. TAHUN, 17. RESEP, 18. BUKU, 19. MATA, 20. LILIN

### Deret 4 (words4)
1. SAYANG, 2. KAMPUS, 3. HARI, 4. OBRAL, 5. KENAL, 6. HAMIL, 7. KITAB, 8. GANTI, 9. SAPI, 10. JERUK, 11. RINDU, 12. HANTU, 13. MADU, 14. SEMIR, 15. SAKIT, 16. LOMBA, 17. PENCAK, 18. BATUK, 19. DEBU, 20. BAKMI

### Deret 5 (words5)
1. ANAK, 2. DARAH, 3. USUL, 4. TEMBAK, 5. MINUM, 6. API, 7. BULAN, 8. KILAT, 9. BERSIH, 10. KUNCI, 11. SEDAP, 12. PASAR, 13. DOKTER, 14. BETON, 15. MULUT, 16. PAGI, 17. AKAL, 18. MISKIN, 19. BARU, 20. KENYANG

### Deret 6 (words6)
1. IMAN, 2. POLA, 3. BUKIT, 4. LIBUR, 5. GADIS, 6. DAPUR, 7. JALAN, 8. PENDEK, 9. CAMBUK, 10. KEMBANG, 11. HALUS, 12. MUMI, 13. SEMUT, 14. KIRI, 15. OTAK, 16. PESTA, 17. RUKUN, 18. NASIB, 19. TANAH, 20. AYAM

### Deret 7 (words7)
1. SUNTIK, 2. BARU, 3. NYAWA, 4. KECAP, 5. BOLA, 6. MAKAN, 7. MURID, 8. SAMPAH, 9. NENEK, 10. LEHER, 11. ASIN, 12. KABEL, 13. SOAL, 14. KAIN, 15. TIDUR, 16. BAIK, 17. GURU, 18. RUMPUT, 19. DIAM, 20. PLASTIK

### Deret 8 (words8)
1. TAKSI, 2. PERUT, 3. NONA, 4. PISANG, 5. HUKUM, 6. MEJA, 7. BADAN, 8. LAMPU, 9. GAMBAR, 10. LISTRIK, 11. UMUM, 12. PENSIL, 13. BUAH, 14. CINA, 15. KOREK, 16. BANTAL, 17. MANDI, 18. BAKUL, 19. KURSI, 20. TEKAD

### Deret 9 (words9)
1. HATI, 2. KOLAM, 3. BUTA, 4. YAKIN, 5. GEMUK, 6. DINAS, 7. BUDI, 8. LUPA, 9. KERIS, 10. KOPI, 11. AMAL, 12. TAMU, 13. LEMBUR, 14. SANDANG, 15. KECIL, 16. BANJIR, 17. PANAS, 18. MURAH, 19. TUAN

### Deret 10 (words10)
1. TEMPO, 2. PINTU, 3. HOTEL, 4. MINYAK, 5. BASAH, 6. MODAL, 7. BERAS, 8. DUKUN, 9. KULIT, 10. BATIK, 11. IKAN, 12. DESA, 13. AIR, 14. KAMPUNG, 15. LINTAH, 16. MACAN, 17. SUMUR, 18. BENSIN, 19. PERAK, 20. LAGU

---

## 6. Flowchart Operasi

### 6.1 Diagram Alur Utama (Main Flowchart)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         POWER ON                                    │
└───────────────────────────┬─────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SETUP()                                         │
│  • Init pins (TrigMic, TrigRlyDF, TrigPower)                        │
│  • Init Serial 9600 baud                                            │
│  • Init TFT SPI (spiTFT.begin)                                       │
│  • Init TFT (tft.initR, tft.setRotation)                             │
│  • Init I2C Wire (SDA=37, SCL=38)                                   │
│  • Setup button modes (INPUT/INPUT_PULLUP)                           │
│  • Init ADC (analogReadResolution 12bit)                             │
│  • Init DFPlayer (mySerial1, myDFPlayer.begin)                       │
│  • Set DFPlayer volume, EQ, output device                           │
│  • Play test file & stop                                            │
│  • Read RTC                                                          │
└───────────────────────────┬─────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        BEGIN()                                       │
│  1. Show Elitech Logo (50x128, white bg) → delay 2000ms             │
│  2. Clear screen (black)                                            │
│  3. Show Whisper Logo (124x128) → delay 1500ms                      │
│  4. Show Menu Interface (156x128)                                    │
│  5. Draw menu selection rectangle                                   │
│  6. Set on = true                                                    │
└───────────────────────────┬─────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        LOOP()                                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ cek buttonPower (long press 2 detik → SHUTDOWN)              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                              ▼                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │    OKE()     │  │   NEXT()     │  │  PREVIOUS()  │             │
│  │ (Pause btn)  │  │  (Next btn)  │  │  (Prev btn)  │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         │                  │                  │                     │
│         ▼                  ▼                  ▼                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   VOLUME()   │  │   MODEE()    │  │    HOME()    │             │
│  │ (Vol+/Vol-)  │  │  (Mode btn)  │  │  (Home btn)  │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         │                  │                  │                     │
│         ▼                  ▼                  ▼                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │    MIC()     │  │  READRTC()   │  │  BAT_CAS()   │             │
│  │ (Dr btn)     │  │ (30 detik)   │  │ (selalu)     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                     │
│         ┌───────────────────────────────────────────────────────┐  │
│         │          JIKA posisi == 2 (SCREENING)                 │  │
│         │  ┌──────────────────┐  ┌──────────────────┐            │  │
│         │  │ autodetect_df() │  │    LIRIK()      │            │  │
│         │  │ (cek status MP3)│  │ (tampilkan kata) │            │  │
│         │  └──────────────────┘  └──────────────────┘            │  │
│         └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Diagram Alur Tombol OK (oke.ino)

```
                    ┌──────────────────┐
                    │  BUTTON PAUSE    │
                    │     (HIGH)       │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   posisi == 1?  │
                    │   (Main Menu)   │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
         ┌─────────┐                  ┌─────────┐
         │   YES   │                  │   NO    │
         └────┬────┘                  └────┬────┘
              │                            │
              ▼                            ▼
    ┌─────────────────┐           ┌──────────────────┐
    │ pilihan == 1?   │           │   posisi == 2?  │
    │ (Screening)     │           │   (Playing)     │
    └────────┬────────┘           └────────┬─────────┘
             │                             │
       ┌─────┴─────┐                  ┌─────┴──────┐
       │           │                  │            │
       ▼           ▼                  ▼            ▼
   ┌───────┐ ┌───────┐          ┌─────────┐ ┌─────────┐
   │  YES  │ │  NO   │          │ isPlay? │ │  STOP   │
   └───┬───┘ └───┬───┘          └────┬────┘ └────┬────┘
       │         │                    │           │
       ▼         ▼                    ▼           ▼
┌────────────┐ ┌────────────┐   ┌──────────┐ ┌──────────┐
│ myDFPlayer │ │ pilihan==2?│   │ PAUSE()  │ │ PLAY()   │
│   .stop()  │ │  (File)    │   │ .pause() │ │ .start() │
└─────┬──────┘ └─────┬──────┘   └────┬─────┘ └────┬─────┘
      │             │                │            │
      ▼             ▼                ▼            ▼
┌───────────┐ ┌───────────┐    ┌──────────┐ ┌──────────┐
│ posisi=2  │ │ posisi=4  │    │ isPlaying│ │isPlaying │
│screening()│ │  file()   │    │ =false   │ │ =true    │
└───────────┘ └───────────┘    └──────────┘ └──────────┘
```

### 6.3 Diagram Alur Navigasi Next (nextp.ino)

```
                ┌──────────────────┐
                │  BUTTON NEXT    │
                │     (HIGH)       │
                └────────┬─────────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         ┌────────┐ ┌────────┐ ┌────────┐
         │posisi=1│ │posisi=2│ │posisi=3│
         │(Menu)  │ │(Playing)│ │(AturJam)│
         └───┬────┘ └────┬───┘ └───┬────┘
             │          │         │
             ▼          ▼         ▼
        ┌────────┐ ┌────────┐ ┌────────┐
        │pilihan++│ │deret++ │ │  jam++ │
        │wrap to 1│ │wrap 1-10│ │wrap 0-23│
        └────┬────┘ └────┬───┘ └────┬───┘
             │          │         │
             ▼          ▼         ▼
        ┌────────┐ ┌────────┐ ┌────────┐
        │ menu() │ │selanjut│ │tampil  │
        │        │ │.()     │ │jam baru│
        └────────┘ └────────┘ └────────┘

    =========================================
    
         JIKA posisi = 4 (File List)
         
                ┌──────────────────┐
                │ selectedIndex++│
                └────────┬───────┘
                         │
                         ▼
                ┌──────────────────┐
                │ >= menuCount?   │
                └────────┬───────┘
                         │
                    ┌────┴────┐
                    ▼         ▼
               ┌───────┐ ┌────────┐
               │  YES  │ │  NO    │
               └───┬───┘ └───┬────┘
                   │         │
                   ▼         ▼
              ┌────────┐ ┌────────┐
              │reset=0 │ │  page= │
              └────────┘ │selected/│
                        │ itemsPer│
                        └────────┘
                              │
                              ▼
                        ┌──────────┐
                        │display() │
                        └──────────┘
```

### 6.4 Diagram Alur Sinkronisasi Lirik (lirik)

```
                    ┌──────────────────────┐
                    │       LIRIK()        │
                    │  (dipanggil di loop) │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   running == false?  │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
               ┌────────┐            ┌────────┐
               │  YES   │            │  NO    │
               └───┬────┘            └───┬────┘
                  │                      │
                  ▼                      ▼
            ┌──────────┐         ┌─────────────┐
            │  RETURN  │         │ elapsedTime │
            │  (stop)  │         │ = millis()  │
            └──────────┘         └──────┬──────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │ currentWord <21 │
                               └────────┬────────┘
                                        │
                               ┌────────┴────────┐
                               ▼                 ▼
                          ┌────────┐        ┌────────┐
                          │  YES   │        │  NO    │
                          └───┬────┘        └───┬────┘
                             │                  │
                             ▼                  ▼
                    ┌──────────────┐   ┌────────────────┐
                    │elapsedTime >=│   │  RETURN        │
                    │ words[].time │   │ (tidak tampil) │
                    └──────┬───────┘   └────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ tft.fillRect │
                    │ (clear area) │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ tft.setCursor│
                    │ tft.print()  │
                    │ (kata baru)  │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ currentWord++│
                    └──────────────┘
```

### 6.5 Diagram Alur Kontrol DFPlayer (autodetect_state_df)

```
                ┌──────────────────────┐
                │ autodetect_state_df()│
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ ind = readState()   │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │   ind != last_ind?   │
                └──────────┬───────────┘
                           │
              ┌────────────┴────────────┐
              ▼                          ▼
        ┌─────────┐                ┌─────────┐
        │   YES   │                │   NO    │
        └────┬────┘                └────┬────┘
             │                          │
             ▼                          ▼
    ┌─────────────────┐         ┌──────────────┐
    │ ind != 513?     │         │ last_ind=ind │
    │ (NOT playing)   │         │    (update)  │
    └────────┬────────┘         └──────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌─────────┐     ┌─────────┐
│   YES   │     │   NO    │
└────┬────┘     └────┬────┘
     │              │
     ▼              ▼
┌──────────┐  ┌──────────┐
│ STOP ICON│  │ PLAY ICON│
│ (rect)   │  │ (tri)    │
│ (pause)  │  │ (bars)   │
└──────────┘  └──────────┘
```

### 6.6 State Machine Diagram (posisi)

```
                    ┌─────────────────┐
                    │    START        │
                    └────────┬────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │     posisi = 1     │
                  │   (Main Menu)       │
                  └──────────┬──────────┘
                             │
         ┌────────┬──────────┴──────────┬────────┐
         │        │                     │        │
         ▼        ▼                     ▼        ▼
    ┌─────────┐┌─────────┐         ┌─────────┐┌─────────┐
    │NEXT/    ││OKE btn  │         │OKE btn  ││NEXT/    │
    │PREV     ││pilihan=1│         │pilihan=3││PREV     │
    │         ││         │         │         ││         │
    └────┬────┘└────┬────┘         └────┬────┘└────┬────┘
         │         │                    │         │
         ▼         ▼                    ▼         ▼
    ┌─────────────────────────────────────────────┐
    │               TRANSISI STATE                 │
    │                                               │
    │   posisi=1 ──OK(pilihan=1)──► posisi=2      │
    │   posisi=1 ──OK(pilihan=2)──► posisi=4      │
    │   posisi=1 ──OK(pilihan=3)──► posisi=3      │
    │   posisi=2 ──HOME────────────► posisi=1    │
    │   posisi=3 ──MODE (save RTC)──► posisi=1    │
    │   posisi=4 ──OKE (select file)► posisi=5    │
    │   posisi=5 ──HOME────────────► posisi=1    │
    └─────────────────────────────────────────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │      STATE          │
                  │                     │
                  │  1: Menu Utama      │
                  │  2: Screening/Lirik │
                  │  3: Atur Jam        │
                  │  4: Daftar File    │
                  │  5: Detail Deret    │
                  └─────────────────────┘
```

### 6.7 Flowchart Pengaturan Waktu (aturjam)

```
                    ┌─────────────────────┐
                    │      ATURJAM()     │
                    │    (OKE -> posisi=3)│
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │ myDFPlayer.stop()  │
                    │ isPlaying = false   │
                    │ posisi = 3          │
                    │ tampil "00:00"      │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   VOL+ (Volume Up)  │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │      menit++        │
                    │    wrap 0-59        │
                    │    update display   │
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │  VOL- (Volume Down) │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │      menit--        │
                    │    wrap 59-0        │
                    │    update display   │
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │   NEXT (Button)     │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │       jam++         │
                    │    wrap 0-23        │
                    │    update display   │
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │  PREV (Button)      │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │       jam--         │
                    │    wrap 23-0        │
                    │    update display   │
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │   MODE (Save)      │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   setRTC(jam,menit) │
                    │   posisi = 1        │
                    │   readRTC()         │
                    └─────────────────────┘
```

### 6.8 Diagram Alur Power Off (readButtonState)

```
                    ┌─────────────────────┐
                    │  readButtonState()  │
                    │   (long press 2s)   │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │  buttonState == LOW │
                    │  && !longPress      │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │ buttonPressDuration │
                    │    > 2000ms?        │
                    └─────────┬───────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              ┌─────────┐         ┌─────────┐
              │   YES   │         │   NO    │
              └───┬─────┘         └───┬─────┘
                  │                   │
                  ▼                   ▼
            ┌───────────┐       ┌───────────┐
            │SHUTDOWN   │       │  RETURN   │
            │PROCESS    │       │ (continue)│
            └─────┬─────┘       └───────────┘
                  │
                  ▼
            ┌───────────┐
            │tft.fill   │
            │"OFF"      │
            └─────┬─────┘
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
   ┌────────┐┌────────┐┌────────┐
   │TrigMic ││TrigRly ││TrigPwr │
   │  LOW   ││  LOW   ││ HIGH   │
   └────────┘└────────┘└────────┘
```

---

## 7. Spesifikasi Teknis

### 7.1 Kebutuhan Daya
- Voltage Input: 5V DC (via USB) atau 3.7V (Battery)
- Current: ~500mA max

### 7.2 Kondisi Operasi
- Suhu: -10°C hingga 60°C
- Storage: -20°C hingga 70°C

### 7.3 Komunikasi
- I2C (Wire): RTC DS3231 pada pin 37 (SDA), 38 (SCL)
- Software Serial: DFPlayer Mini pada pin 35 (RX), 36 (TX)
- SPI: TFT Display pada HSPI

### 7.4 Penyimpanan Data
- Flash PROGMEM: Bitmap logo dan icon
- SD Card: File audio MP3 untuk DFPlayer

---

## 8. Struktur Folder SD Card (DFPlayer)

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

## 9. Troubleshooting

### 9.1 Masalah Umum

| Masalah | Kemungkinan Cause | Solusi |
|---------|-------------------|--------|
| TFT tidak muncul | Wiring SPI salah | Periksa pin MOSI, SCK, CS |
| DFPlayer tidak suara | SD card tidak terbaca | Format SD card FAT16/32 |
| RTC tidak sinkron | Wiring I2C salah | Periksa SDA, SCL connection |
| Lirik tidak sinkron | Timing tidak sesuai | Sesuaikan nilai time di array words |
| Battery tidak terdisplay | ADC pin salah | Periksa wiring dan software |

### 9.2 Debugging

Serial monitor pada 9600 baud menampilkan:
- Button press states
- DFPlayer state (ind)
- Volume changes
- Menu navigation

---

## 10. Referensi Library

- [Adafruit ST7735](https://github.com/adafruit/Adafruit-ST7735-Library)
- [Adafruit GFX](https://github.com/adafruit/Adafruit-GFX-Library)
- [DFRobot DFPlayer Mini](https://github.com/DFRobot/DFRobotDFPlayerMini)
- [RTClib](https://github.com/adafruit/RTClib)

---

## 11. Alur User (User Flow)

Karena perangkat ini dirancang untuk **audio screening** (pemeriksaan pendengaran), pemahaman alur penggunaan sangat penting untuk memastikan operasi yang efisien dan hasil screening yang akurat.

### 11.1 Alur Utama Pengguna (Main User Flow)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PEMAKAIAN PERANGKAT                                  │
│                    (Audio Screening Device)                                  │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │       POWER ON              │
                    │   (Splash Logo Elitech)     │
                    └─────────────┬───────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │   (Splash Logo Whisper)     │
                    │         ↓ 1.5s              │
                    └─────────────┬───────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MENU UTAMA                                        │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                   │
│  │ ▶ Screening   │  │   ▶ File     │  │  ▶ Atur Jam   │                   │
│  └───────────────┘  └───────────────┘  └───────────────┘                   │
│                                                                             │
│        NEXT/Prev untuk navigasi    │    OKE untuk pilih                     │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │ SCREENING   │        │ FILE LIST   │        │ ATUR JAM    │
   │ (posisi=2)  │        │ (posisi=4)  │        │ (posisi=3)  │
   └──────┬──────┘        └──────┬──────┘        └──────┬──────┘
          │                       │                       │
          ▼                       ▼                       ▼
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │ 1. Pilih    │        │ Pilih Deret │        │ Atur Waktu  │
   │    Mode     │        │ 1-10        │        │ +Volume Up  │
   │ (All/Kiri/  │        │             │        │ -Volume Down│
   │  Kanan)     │        └──────┬──────┘        │ ↑Next=jam++ │
   │             │               │               │ ↓Prev=jam-- │
   └──────┬──────┘               │               │ MODE=simpan │
          │                       ▼               └─────────────┘
          ▼               ┌─────────────┐
   ┌─────────────┐        │ DETAIL      │
   │ 2. Pilih    │        │ DERRT       │
   │    Deret    │        │ (posisi=5)  │
   │   (1-10)   │        └─────────────┘
   │             │
   └──────┬──────┘
          │
          ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │                         MODE SCREENING AKTIF                            │
   │                                                                          │
   │  ┌──────────────────────────────────────────────────────────────────┐   │
   │  │                    TAMPILAN LYRIK SYNC                           │   │
   │  │                                                                  │   │
   │  │    [●] SABUN  KUDA  DINGIN  BANYAK  GULA  PIPI  BESAR  ...     │   │
   │  │         ▲                                                         │   │
   │  │    kata aktif                                                     │   │
   │  └──────────────────────────────────────────────────────────────────┘   │
   │                                                                          │
   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
   │  │    [HOME]       │  │    [OKE]        │  │    [MODE]       │          │
   │  │  Kembali Menu   │  │  Play / Pause   │  │  Ganti Mode     │          │
   │  └─────────────────┘  └─────────────────┘  └─────────────────┘          │
   │                                                                          │
   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
   │  │   [NEXT]        │  │   [PREV]        │  │   [DOKTER]      │          │
   │  │  Deret Berikut  │  │  Deret Sebelumnya│  │  Mode Mic ON   │          │
   │  └─────────────────┘  └─────────────────┘  └─────────────────┘          │
   │                                                                          │
   │  ┌─────────────────┐  ┌─────────────────┐                               │
   │  │  [VOL+]        │  │  [VOL-]         │                               │
   │  │  Volume Naik   │  │  Volume Turun   │                               │
   │  └─────────────────┘  └─────────────────┘                               │
   └─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Skenario Penggunaan Tipikal

#### Skenario 1: Pemeriksaan Screening Standar

```
TAHAPAN                          AKSI PENGGUNA                  HASIL
─────────────────────────────────────────────────────────────────────────
1. Persiapan                     Nyalakan perangkat             Splash → Menu Utama
2. Pilih Menu                     NEXT → Screening → OKE         Masuk mode screening
3. Pilih Mode                     MODE (pilih All/Kiri/Kanan)   Mode tersimpan
4. Pilih Deret                    NEXT/PREV (1-10)              Deret dipilih
5. Mulai Pemutaran               OKE (Play)                    Musik & lirik berjalan
6. Rekam Respons                  [Pengguna merekam respons]    Kata ditampilkan sinkron
7. Jeda (jika perlu)              OKE (Pause)                   Musik berhenti
8. Lanjut/Lain Deret              NEXT/PREV                     Pindah deret
9. Selesai                        HOME                          Kembali ke Menu
```

#### Skenario 2: Pemeriksaan Mode Telinga Kiri

```
TAHAPAN                          AKSI PENGGUNA                  HASIL
─────────────────────────────────────────────────────────────────────────
1. Pilih Menu Screening          NEXT → OKE                     Masuk screening
2. Pilih Mode Kiri                MODE (2x) → Mode=Kiri         Indicator "KIRI"
3. Pilih Deret                    NEXT (misal: Deret 3)          Deret 3 terpilih
4. Mulai                          OKE                            Musik folder 02/003.mp3
5. Pasang Headphone              [Pengguna pasang di telinga    Audio dari DFPlayer
                                 kiri]                          Output mono/specific
6. Catat Respons                 [Rekam hasil screening]        -
7. Selesai                       HOME                            Kembali menu
```

#### Skenario 3: Mode Dokter (Komunikasi)

```
TAHAPAN                          AKSI PENGGUNA                  HASIL
─────────────────────────────────────────────────────────────────────────
1. Screening Berjalan            Musik & lirik aktif            Audio playing
2. Aktifkan Mode Dokter           Tekan tombol DOKTER             TrigMic = HIGH
3. Mic ON Indicator               [Tampil di LCD]                Icon mic aktif
4. Berbicara ke Pasien            [Dokter bicara via mic]        Audio mic ke headphone
5. Matikan Mode Dokter            Tekan lagi tombol DOKTER       TrigMic = LOW
6. Lanjut Screening               Musik resumes                   Resume playing
```

#### Skenario 4: Pengaturan Waktu RTC

```
TAHAPAN                          AKSI PENGGUNA                  HASIL
─────────────────────────────────────────────────────────────────────────
1. Dari Menu Utama                NEXT → NEXT → OKE (Atur Jam)   Masuk mode Atur Jam
2. Atur Menit                     VOL+ / VOL-                    Menit +1/-1 (wrap 0-59)
3. Konfirmasi Menit               NEXT                           Pindah ke jam
4. Atur Jam                       NEXT / PREV                    Jam +1/-1 (wrap 0-23)
5. Simpan Pengaturan              MODE                           Waktu tersimpan ke RTC
6. Kembali Menu                   HOME                           Menu Utama
```

### 11.3 Tabel Feedback Visual Sistem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FEEDBACK VISUAL LCD                              │
├──────────────────────┬──────────────────────────────────────────────────────┤
│ KONDISI SISTEM       │ FEEDBACK TAMPILAN                                   │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Power On             │ Logo Elitech (2s) → Logo Whisper (1.5s) → Menu      │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Menu Utama           │ 3 pilihan: Screening, File, Atur Jam (highlight)    │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Mode Screening       │ Tampilan lirik + play icon + deret + mode + jam     │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Playing              │ ▶ (triangle) icon, kata berganti sinkron             │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Paused               │ ▮▮ (rectangle) icon, lirik frozen                    │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Mode = All           │ Text "ALL" di display                                │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Mode = Kiri          │ Text "KIRI" di display                               │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Mode = Kanan         │ Text "KANAN" di display                              │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Mode Dokter ON       │ Icon mic + text "DOKTER"                             │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Volume Up            │ t_loud +1 (range 0-30), bar graph                    │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Volume Down          │ t_loud -1 (range 0-30), bar graph                    │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Battery Low          │ Icon battery + warning (jika <20%)                   │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Charging             │ Icon charging (jika CHRG pin LOW)                     │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ Power Off            │ Layar "OFF" (setelah long press 2s)                  │
└──────────────────────┴──────────────────────────────────────────────────────┘
```

### 11.4 Diagram Interaksi Pengguna-Peran

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PERAN PENGGUNA & INTERAKSI                               │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │   DOKTER     │
    │  (Operator)  │
    └──────┬───────┘
           │
           │ Mengoperasikan perangkat
           │ Memberikan instruksi lisan (mode dokter)
           │ Merekam hasil screening
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ESP32-S3 LIRIK PLAYER                                 │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                   │
│  │  TAMPILAN   │    │   KONTROL   │    │   AUDIO     │                   │
│  │  LCD 128x160│    │   TOMBOL    │    │  DFPlayer   │                   │
│  └─────────────┘    └─────────────┘    └─────────────┘                   │
│                                                                             │
│  Menampilkan:              Menghandle:           Output:                  │
│  - Lirik sync              - NEXT/PREV           - Musik MP3               │
│  - Menu                    - OKE/PAUSE           - Mode dokter (mic)       │
│  - Status                  - HOME                                            │
│  - Jam & Battery           - MODE                                           │
│                            - VOL+/-                                         │
│                            - DOKTER                                         │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           │ Hasil screening audio
           │ (kata yang didengar & direspons)
           │
           ▼
    ┌──────────────┐
    │   PASIEN     │
    │(Yang disksrining)│
    └──────────────┘
```

---

## 12. Catatan Pengembangan

- Project ini menggunakan Arduino IDE dengan board ESP32
- File bitmap disimpan dalam format uint16_t array di PROGMEM
- Sistem timer menggunakan millis() untuk sinkronisasi lirik
- Untuk pengembangan lanjut, bisa menambahkan:
  - Bluetooth control
  - WiFi update lyric
  - OTA firmware update