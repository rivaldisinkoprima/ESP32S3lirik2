#include "Fonts/FreeSans9pt7b.h" // Font tambahan
#include "Fonts/Org_01.h"        // Font tambahan
#include "HardwareSerial.h"
#include "RTClib.h"

// ============================================================
// OPSI 1: Sync Jam RTC dari Waktu Kompilasi
// Set ke 1 SEKALI saat pertama kali upload untuk mengatur jam.
// Set kembali ke 0 setelah jam benar, lalu upload ulang.
// Jika tetap 1, jam akan di-reset setiap boot!
// ============================================================
#define SYNC_RTC_ON_BOOT 1 // Ubah ke 1 untuk sync, 0 untuk normal
#include "driver/adc.h"
#include <Adafruit_GFX.h>    // Core graphics library
#include <Adafruit_ST7735.h> // Hardware-specific library for ST7735
#include <Arduino.h>
#include <DFRobotDFPlayerMini.h>
#include <SD.h>
#include <SPI.h>
#include <SoftwareSerial.h>
#include <Wire.h>

// BLE and LittleFS
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <FS.h>
#include <LittleFS.h>
#include <esp_task_wdt.h>

enum ChargerState { NOT_CHARGING, CHARGING, FULL };

// Deklarasi fungsi UI untuk dipanggil di ble_server.ino
void showSyncingUI(int slot, int total);
void hideSyncingUI();
void drawBTIcon();
bool isSyncing = false; // Flag untuk menandai sedang sync

// RTC Object (RTClib) — dipakai untuk Opsi 1 (boot sync) & Opsi 3 (BLE sync)
RTC_DS3231 rtcLib;
// Note: decToBcd & bcdToDec sudah ada di mode.ino, tidak perlu redefinisi

// Tulis jam/menit/detik langsung ke DS3231 via I2C raw
// Dipanggil dari: Opsi 1 (boot) & BLE @SET_TIME command
void setRtcTime(byte h, byte m, byte s) {
  Wire.beginTransmission(0x68); // DS3231 I2C address
  Wire.write(0x00);
  extern byte decToBcd(byte val);
  Wire.write(decToBcd(s));
  Wire.write(decToBcd(m));
  Wire.write(decToBcd(h));
  Wire.endTransmission();

  // INVALIDASI cache jam sebelumnya agar loop berikutnya memaksa TFT ter-refresh
  extern int l_minute;
  extern int l_hour;
  l_minute = -1;
  l_hour = -1;

  Serial.printf("[RTC] Jam diset ke %02d:%02d:%02d\n", h, m, s);
}

HardwareSerial mySerial1(1);

#define TFT_CS 13
#define TFT_RST 12
#define TFT_DC 11
#define TFT_MOSI 10
#define TFT_SCK 15
#define TFT_MISO -1

#define PIN_CHRG 45
#define PIN_STBY 48

#define DS3231_ADDRESS 0x68 // Alamat default RTC DS3231

#define BAT_ADC_PIN 5

#define BATT_X 100
#define BATT_Y 3

SPIClass spiTFT(
    FSPI); // FSPI = SPI2 pada ESP32-S3 (HSPI tidak punya default pins di S3!)
Adafruit_ST7735 tft = Adafruit_ST7735(&spiTFT, TFT_CS, TFT_DC, TFT_RST);

// ⚠️  GPIO 35 & 36 = PSRAM Octal data lines di ESP32-S3 N16R8, TIDAK BISA
// dipakai! Pin DFPlayer dipindah ke GPIO yang aman (di luar range 26-37)
static const uint8_t PIN_MP3_TX = 41; // TX ke DFPlayer RX (GPIO aman)
static const uint8_t PIN_MP3_RX = 16;  // RX dari DFPlayer TX (GPIO aman)
// SoftwareSerial mySoftwareSerial(PIN_MP3_RX, PIN_MP3_TX); // ← DINONAKTIFKAN:
// tidak dipakai

DFRobotDFPlayerMini myDFPlayer;

int buttonNext = 4;
int buttonPause = 3; // PB5;
int buttonHome = 1;
int buttonPrevious = 2;
int buttonVolup = 18;
int buttonVoldown = 9;
int buttonMode = 6; // PB3;
int buttonMDokter = 19;
// int buttonMPasien = 5;
int buttonPower = 46;
int TrigMic = 8;    /////
int TrigPower = 21; /////////
int TrigRlyDF = 20; ///////////
int pinLED = 55;    // PB12;
int pinBatt = 45;   ///////

int last_percent = 0;

int ind;
int last_ind = 5;
int loud = 13;
int t_loud = 35;
int menit = 0;
int l_minute, l_hour, jam;

int posisi = 1;  // 1 = menu utama
int pilihan = 1; // posisi cursor sesuai urutan
int lastDeret = 0;
int deret = 1;
int mode = 1; // 1 = seluruhnya 2= kanan 3 = kiri

boolean isPlaying;
bool on = false;
unsigned long currentMillis; // Variabele to store the number of milleseconds
                             // since the Arduino has started
unsigned long currentMillis2;

bool dokter_bicara = false;

ChargerState lastState = NOT_CHARGING;
ChargerState currentState;

// === Dynamic Memory Profile (ADAPTIF — dihitung dari PSRAM fisik saat boot)
// ===
size_t totalPsramSize = 0;     // Diisi saat boot dari ESP.getPsramSize()
size_t safePsramThreshold = 0; // 10% dari totalPsramSize (cadangan minimum)
size_t totalFlashSize = 0;     // LittleFS total capacity
const size_t SAFE_FLASH_MIN = 50 * 1024; // Minimal 50KB sisa flash
const size_t SAFE_HEAP_MIN = 32768;      // Minimal 32KB internal heap

// === Dynamic Slot Management ===
int activeDaretCount = 10; // Default fallback (di-update saat boot & sync)

unsigned long lastRTC = 0;
int lastBatteryUpdate = 0;

unsigned long startTime = 0;
unsigned long elapsedTime = 0;
int currentWord = 0;

struct Word {
  float time;
  const char *text;
};

Word *words;

// === Semua data lirik disimpan di LittleFS, tidak ada hardcoded ===

bool running = false;
bool wordsFromLittleFS =
    false; // Track apakah words saat ini dari LittleFS (perlu di-free)
int loadedWordCount =
    21; // Jumlah elemen aktif dalam array words[] (termasuk header)
unsigned long lastButtonTime =
    0; // Timestamp terakhir tombol ditekan (debounce)
const unsigned long DEBOUNCE_MS =
    250; // Minimum interval antar tekan tombol (ms)

// --- FORWARD DECLARATIONS UNTUK PLATFORMIO ---
void volume();
void sesion();
void oke();
void nextp();
void previouse();
void modee();
void home();
void mic();
void autodetect_state_df();
void lirik();
void readRTC();
void bat_cas();
void bat_cas_move();
void readButtonState();
void aturjam();
void tampiljam();
void file();
void listderet();
void begin();
void initBLE();
void handleBLE();
bool initLittleFS();
bool deretExistsInLittleFS(int slot);
Word *loadDeretFromLittleFS(int slot);
void listLirikFiles();
void freeLoadedWords();
void displayDeretGeneric(int deretIndex, int page);
int getDeretPageCount(int deretIndex);
bool processDeret(JsonObject deret);
void notifyStatus(const char *status);
bool saveDeretToLittleFS(int slot, const String &name, const String &jsonWords);
void sendCheckPayload();
String buildCheckPayload();
void initMemoryProfile();
int scanDeretSlots();
bool checkMemorySafety();
// ---------------------------------------------

/**
 * Baca kapasitas PSRAM/Heap dari hardware saat boot.
 * Threshold 90% dihitung dinamis — adaptif terhadap upgrade HW.
 *
 * Contoh:
 *   PSRAM 8MB  → cadangan min 800KB (threshold = 7.2MB)
 *   PSRAM 16MB → cadangan min 1.6MB (threshold = 14.4MB)
 */
void initMemoryProfile() {
  totalPsramSize = ESP.getPsramSize();
  safePsramThreshold =
      totalPsramSize / 10; // 10% dari total = batas sisa minimum

  Serial.println("\n========= MEMORY PROFILE =========");
  Serial.printf("  Heap Total  : %u bytes\n", ESP.getHeapSize());
  Serial.printf("  Heap Free   : %u bytes\n", ESP.getFreeHeap());
  Serial.printf("  PSRAM Total : %u bytes (%.1f MB)\n", totalPsramSize,
                totalPsramSize / 1048576.0);
  Serial.printf("  PSRAM Free  : %u bytes\n", ESP.getFreePsram());
  Serial.printf("  PSRAM Gate  : %u bytes (10%% reserved)\n",
                safePsramThreshold);
  Serial.println("==================================");
}

void setup() {
  Serial.begin(115200);
  delay(1000);          // Beri waktu serial stabil
  esp_task_wdt_reset(); // ① Feed WDT setelah delay awal

  initMemoryProfile(); // ★ PERTAMA: baca kapasitas memori hardware

  pinMode(TrigMic, OUTPUT);
  pinMode(TrigRlyDF, OUTPUT);
  digitalWrite(TrigMic, LOW);
  digitalWrite(TrigRlyDF, LOW);
  delay(200);
  pinMode(TrigPower, OUTPUT);
  digitalWrite(TrigPower, HIGH);
  pinMode(14, INPUT);
  spiTFT.begin(TFT_SCK, TFT_MISO, TFT_MOSI, TFT_CS);
  tft.initR(INITR_BLACKTAB);
  tft.setRotation(2);
  pinMode(17, OUTPUT);
  digitalWrite(17, HIGH);
  Wire.begin(39, 40); // SDA=39, SCL=40 (Dipindah karena GPIO 37 & 38 bentrok
                      // dengan data line PSRAM Octal!)

#if SYNC_RTC_ON_BOOT
  if (rtcLib.begin()) {
    rtcLib.adjust(DateTime(F(__DATE__), F(__TIME__)));
    Serial.println("[RTC] OPSI 1: Jam otomatis dimutakhirkan dengan jam PC "
                   "(waktu kompilasi)!");
  } else {
    Serial.println("[RTC] Gagal menemukan DS3231 saat boot sync.");
  }
#endif

  readRTC(); // ★ Baca jam RTC SEBELUM splash screen agar tampiljam()
             // menampilkan waktu yang benar
  begin();
  esp_task_wdt_reset(); // ② Feed WDT setelah splash screen (4200ms delays di
                        // begin())
  // digitalWrite(buttonNext, LOW); // Jangan ditarik low jika ingin pakai
  // Pullup
  pinMode(buttonNext, INPUT_PULLUP);
  pinMode(buttonPause, INPUT_PULLUP);
  /*
  pinMode(buttonHome, INPUT);
  pinMode(buttonPrevious, INPUT);
  gpio_pulldown_en(GPIO_NUM_2); // aktifkan internal pull-down
  gpio_pullup_dis(GPIO_NUM_2);  // pastikan pull-up dimatikan
  pinMode(buttonVolup, INPUT);
  pinMode(buttonVoldown, INPUT);
  pinMode(buttonMode, INPUT);
  gpio_pulldown_en(GPIO_NUM_6); // aktifkan internal pull-down
  gpio_pullup_dis(GPIO_NUM_6);  // pastikan pull-up dimatikan
  */
  pinMode(buttonMDokter, INPUT);
  // pinMode(buttonMPasien,INPUT);
  pinMode(buttonPower, INPUT_PULLUP);
  pinMode(PIN_CHRG, INPUT_PULLUP);
  pinMode(PIN_STBY, INPUT_PULLUP);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  for (int i = 0; i < 20; i++) {
    analogRead(BAT_ADC_PIN);
    delay(10);
  }

  // --- BARU BOLEH GAMBAR ---
  // currentState = getChargerState();
  // drawBatteryScreen(currentState);
  // lastState = currentState;

  mySerial1.begin(
      9600, SERIAL_8N1, PIN_MP3_RX,
      PIN_MP3_TX); // RX=GPIO7, TX=GPIO16 (aman, di luar range PSRAM 26-37)
  mySerial1.setTimeout(1000);
  delay(500);
  esp_task_wdt_reset(); // ③ Feed WDT sebelum DFPlayer
  Serial.println("Initializing DFPlayer ...");

#if DFPLAYER_ENABLED
  if (!myDFPlayer.begin(mySerial1, /*isACK=*/false,
                        /*isListenOnlyMode=*/true)) {
    Serial.println(F("DFPlayer tidak ditemukan (Skip untuk testing)"));
  } else {
    Serial.println(F("DFPlayer terdeteksi!!!"));
    myDFPlayer.volume(loud);
    myDFPlayer.EQ(DFPLAYER_EQ_NORMAL);
    myDFPlayer.outputDevice(DFPLAYER_DEVICE_SD);
    myDFPlayer.playFolder(1, 1);
    delay(200);
    myDFPlayer.stop();
  }
#else
  // ★ KRITIS: HARUS tetap panggil begin() meskipun hardware tidak terhubung!
  // Tanpa ini, internal pointer _serial di DFPlayer library = NULL.
  // Setiap panggilan myDFPlayer.stop()/play()/pause() di kode lain
  // akan memanggil sendStack() → write ke NULL → LoadProhibited crash!
  myDFPlayer.begin(mySerial1, /*isACK=*/false, /*isListenOnlyMode=*/true);
  Serial.println(F("[SETUP] DFPlayer: begin() called (stream registered), "
                   "hardware SKIPPED"));
#endif
  mySerial1.setTimeout(1000);
  esp_task_wdt_reset();        // ④ Feed WDT setelah DFPlayer selesai
  tft.setFont(&FreeSans9pt7b); // Atur font
  tft.setTextSize(1);
  readRTC();
  digitalWrite(TrigMic, HIGH);
  digitalWrite(TrigRlyDF, HIGH);

  // Initialize LittleFS
  if (initLittleFS()) {
    Serial.println("[SETUP] LittleFS ready for lyrics storage");

    // ★ Dynamic slot count dari LittleFS
    activeDaretCount = scanDeretSlots();

    // ★ Update flash diagnostics (LittleFS sudah mount)
    totalFlashSize = LittleFS.totalBytes();

    // Debug output diganti untuk menghindari spam LittleFS.exists()
    Serial.println("[SETUP] Filesystem loaded.");

    Serial.println("[SETUP] === STORAGE SUMMARY ===");
    Serial.printf("[SETUP]   Active Derets : %d\n", activeDaretCount);
    Serial.printf("[SETUP]   Flash Total   : %u bytes\n", totalFlashSize);
    Serial.printf("[SETUP]   Flash Used    : %u bytes\n", LittleFS.usedBytes());
    Serial.printf("[SETUP]   Flash Free    : %u bytes\n",
                  totalFlashSize - LittleFS.usedBytes());
    Serial.println("[SETUP] =============================");
  } else {
    Serial.println(
        "[SETUP] WARNING: LittleFS failed, using hardcoded data only");
  }

  esp_task_wdt_reset(); // ⑤ Feed WDT sebelum BLE init
  // Initialize BLE Server
  initBLE();

  Serial.println("[SETUP] ========================================");
  Serial.println("[SETUP] System initialization COMPLETE");
  Serial.printf("[SETUP]   Free Heap : %u bytes\n", ESP.getFreeHeap());
  Serial.printf("[SETUP]   Free PSRAM: %u bytes\n", ESP.getFreePsram());
  Serial.printf("[SETUP]   Slots     : %d\n", activeDaretCount);
  Serial.println("[SETUP] ========================================");
}

void menu(int pilihan) {
  tft.drawRect(0, 25, 67, 60, ST77XX_BLACK);
  tft.drawRect(63, 58, 65, 60, ST77XX_BLACK);
  tft.drawRect(0, 93, 65, 60, ST77XX_BLACK);
  if (pilihan == 1) {
    tft.drawRect(0, 25, 67, 60, ST77XX_CYAN);
  }
  if (pilihan == 2) {
    tft.drawRect(63, 58, 65, 60, ST77XX_CYAN);
  }
  if (pilihan == 3) {
    tft.drawRect(0, 93, 65, 60, ST77XX_CYAN);
  }
}

void screening() {
  posisi = 2;
  //
  tampiljam();
  tft.setCursor(40, 13);
  // tft.print("Screening");
  tft.setCursor(5, 35);
  tft.print("Deret:");
  tft.setCursor(73, 35);
  tft.print(deret);
  tft.setCursor(5, 55);
  tft.print("Mode:");
  tft.setCursor(73, 55);
  if (mode == 1)
    tft.print("Kanan");
  else if (mode == 2)
    tft.print("Kiri");
  else
    tft.print("All");
  // tft.fillRect(5,85,117,5,ST77XX_WHITE);
  tft.drawCircle(64, 115, 18, ST77XX_WHITE);
  tft.fillTriangle(90, 105, 90, 123, 107, 114, ST77XX_WHITE);
  tft.fillTriangle(100, 105, 100, 123, 117, 114, ST77XX_WHITE);
  tft.fillTriangle(38, 105, 38, 123, 21, 114, ST77XX_WHITE);
  tft.fillTriangle(28, 105, 28, 123, 11, 114, ST77XX_WHITE);
  tft.fillTriangle(23, 136, 23, 150, 10, 143, ST77XX_WHITE);
  tft.fillRect(10, 140, 7, 10, ST77XX_BLACK);
  tft.fillRect(13, 140, 3, 7, ST77XX_WHITE);
  tft.setCursor(30, 148);

  // Serial.println(myDFPlayer.readVolume());
  tft.println(t_loud);
}

void loop() {
  // Reset watchdog untuk mencegah trigger
  esp_task_wdt_reset();

  // KUNCI AKSES: Jika sedang sinkronisasi via Bluetooth,
  // Core 1 dilarang memproses UI (Jam, Baterai, dll) & Tombol.
  // Ini mengamankan jalur layar (SPI) agar tidak terjadi Tabrakan/Deadlock.
  if (isSyncing) {
    vTaskDelay(10 /
               portTICK_PERIOD_MS); // Mengalah (yield) agar system tidak marah
    return;
  }

  handleBLE(); // Tangani data Bluetooth yang masuk

  // Update Status Bluetooth di Layar secara berkala
  static unsigned long lastBTCheck = 0;
  if (millis() - lastBTCheck > 1000) {
    drawBTIcon();
    lastBTCheck = millis();
  }

  if (digitalRead(buttonPower) == LOW) {
    if (on == true) {
      // isPlaying = false;
      currentMillis = millis(); // store the current time
      readButtonState();
    }
  }
  /////////////////////////////////button pause / oke ////////////////////////
  oke();
  /////////////////////////////////button next ////////////////////////
  nextp();
  /*
  /////////////////////////////////button previous ////////////////////////
  previouse();
  /////////////////////////////////button volume up ////////////////////////
  volume();
  /////////////////////////////////button mode ////////////////////////
  modee();
  // ///////////////////////////////button home ////////////////////////
  home();
  */
  // ////////////////////////////////////////mic//////////////////////////////
  mic();
  if (posisi == 2) {
    autodetect_state_df();
    if (ind == 513) {
      lirik();
      // currentMillis2 = millis();
      // if (currentMillis2 - lastChange >= interval) {
      // lastChange = currentMillis2;

      // // Hapus layar dan tampilkan pesan baru
      // tft.fillRect(8, 70, 150, 20, ST77XX_BLACK);
      // tft.setCursor(10, 85);
      // tft.setTextColor(ST77XX_YELLOW);
      //   if (deret==1)tft.println(deret1[currentIndex]);
      //   if (deret==2)tft.println(deret2[currentIndex]);
      //   if (deret==3)tft.println(deret3[currentIndex]);
      //   if (deret==4)tft.println(deret4[currentIndex]);
      //   if (deret==5)tft.println(deret5[currentIndex]);
      //   if (deret==6)tft.println(deret6[currentIndex]);
      //   if (deret==7)tft.println(deret7[currentIndex]);
      //   if (deret==8)tft.println(deret8[currentIndex]);
      //   if (deret==9)tft.println(deret9[currentIndex]);
      //   if (deret==10)tft.println(deret10[currentIndex]);

      // tft.setTextColor(ST77XX_WHITE);

      // currentIndex++;
      // if (currentIndex >= totalMessages) {
      //   currentIndex = 0;
      // }}
    }
  }

  if (millis() - lastRTC >= 30000) { // baca setiap 30 menit
    lastRTC = millis();
    readRTC(); // fungsi membaca DS1307 / DS3231
  }
  bat_cas();
}

void selanjutnya() {
  tft.fillRect(8, 70, 150, 20, ST77XX_BLACK);
  currentWord = 0;
  tft.fillTriangle(90, 105, 90, 123, 107, 114, ST77XX_GREEN);
  tft.fillTriangle(100, 105, 100, 123, 117, 114, ST77XX_GREEN);
  delay(200);
  tft.fillRect(70, 15, 70, 25, ST77XX_BLACK);
  tft.setCursor(73, 35);
  deret++;
  if (deret > activeDaretCount)
    deret = 1;
  tft.setTextSize(1);
  tft.print(deret);
  tft.fillTriangle(90, 105, 90, 123, 107, 114, ST77XX_WHITE);
  tft.fillTriangle(100, 105, 100, 123, 117, 114, ST77XX_WHITE);

  if (isPlaying) {
    tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
    tft.fillRect(57, 107, 5, 18, ST77XX_WHITE);
    tft.fillRect(68, 107, 5, 18, ST77XX_WHITE);
  }
  if (isPlaying == false) {
    tft.fillRect(57, 107, 5, 18, ST77XX_BLACK);
    tft.fillRect(68, 107, 5, 18, ST77XX_BLACK);
    tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
  }
}

void sebelumnya() {
  tft.fillRect(8, 70, 150, 20, ST77XX_BLACK);
  currentWord = 0;
  tft.fillTriangle(38, 105, 38, 123, 21, 114, ST77XX_GREEN);
  tft.fillTriangle(28, 105, 28, 123, 11, 114, ST77XX_GREEN);
  delay(200);
  tft.fillRect(70, 15, 70, 25, ST77XX_BLACK);
  tft.setCursor(73, 35);
  deret--;
  if (deret <= 0)
    deret = activeDaretCount;
  tft.setTextSize(1);
  tft.print(deret);
  tft.fillTriangle(38, 105, 38, 123, 21, 114, ST77XX_WHITE);
  tft.fillTriangle(28, 105, 28, 123, 11, 114, ST77XX_WHITE);

  if (isPlaying) {
    tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
    tft.fillRect(57, 107, 5, 18, ST77XX_WHITE);
    tft.fillRect(68, 107, 5, 18, ST77XX_WHITE);
  }
  if (isPlaying == false) {
    tft.fillRect(57, 107, 5, 18, ST77XX_BLACK);
    tft.fillRect(68, 107, 5, 18, ST77XX_BLACK);
    tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
  }
}

void lirik() {

  if (!running || words == NULL)
    return; // Guard: jangan akses pointer NULL

  elapsedTime = millis() - startTime;

  // Lakukan pengecekan bounds ganda
  if (currentWord >= 0 && currentWord < loadedWordCount) {
    if (words[currentWord].text != NULL &&
        elapsedTime >= words[currentWord].time) {
      tft.fillRect(8, 70, 150, 20, ST77XX_BLACK);
      tft.setCursor(10, 85);
      tft.print(words[currentWord].text);
      currentWord++;
    }
  }
  lastDeret = deret;
}

void startCounter() {
  startTime = millis() - elapsedTime;
  running = true;
}

void pauseCounter() {
  elapsedTime = millis() - startTime;
  running = false;
}

void stopCounter() {
  running = false;
  elapsedTime = 0;
  currentWord = 0;
  lastDeret = 0;
}

// Free memory dari words yang di-load dari LittleFS
void freeLoadedWords() {
  if (wordsFromLittleFS && words != NULL) {
    // Free setiap string
    for (int i = 0; i < loadedWordCount; i++) {
      if (words[i].text != NULL) {
        free((void *)words[i].text); // strdup uses malloc
      }
    }
    // Free array struct
    delete[] words;
    words = NULL;
    wordsFromLittleFS = false;
    Serial.print("[MEM] Freed. Heap free: ");
    Serial.print(ESP.getFreeHeap());
    Serial.println(" B");
  }
}

void listderet() {
  // Selalu bersihkan data sebelumnya
  freeLoadedWords();

  // Muat dari LittleFS
  if (deretExistsInLittleFS(deret)) {
    Word *loaded = loadDeretFromLittleFS(deret);
    if (loaded != NULL) {
      words = loaded;
      wordsFromLittleFS = true;
      return;
    }
  }

  // Slot tidak ada di LittleFS - bersihkan pointer
  words = NULL;
  wordsFromLittleFS = false;
  loadedWordCount = 0;
  Serial.print("[DERET] Slot ");
  Serial.print(deret);
  Serial.println(" tidak ada di LittleFS.");
}

// --- FUNGSI UI BLE (TFT) ---
void drawBTIcon() {
  extern bool bleConnected;
  extern bool isSyncing;

  // Skip update icon jika sedang sync agar tidak ada race condition
  if (isSyncing)
    return;

  int x = 60; // Spasi aman dari jam
  int y = 1;  // Koordinat Y diangkat ke atas agar lebih pas
  int w = 5;  // Lebar ikon
  int h = 8;  // Tinggi ikon 8px tetap agar proporsional jam

  if (bleConnected) {
    uint16_t color = ST77XX_CYAN;

    // Simbol Bluetooth (Fine-Tuned 8px Alignment)
    tft.drawLine(x + w / 2, y, x + w / 2, y + h, color);         // Vertikal
    tft.drawLine(x + w / 2, y, x + w, y + h / 4, color);         // Atas
    tft.drawLine(x + w, y + h / 4, x, y + 3 * h / 4, color);     // Silang bawah
    tft.drawLine(x, y + h / 4, x + w, y + 3 * h / 4, color);     // Silang atas
    tft.drawLine(x + w, y + 3 * h / 4, x + w / 2, y + h, color); // Bawah
  } else {
    // Hapus total area bluetooth jika putus
    tft.fillRect(x, y - 1, w + 2, h + 2, ST77XX_BLACK);
  }
}

void showSyncingUI(int slot, int total) {
  isSyncing = true;
  tft.fillRect(0, 40, 128, 80, ST77XX_BLACK);
  tft.drawRect(5, 45, 118, 70, ST77XX_CYAN);

  tft.setFont(NULL); // Gunakan font standar agar cepat
  tft.setTextColor(ST77XX_WHITE);
  tft.setCursor(15, 55);
  tft.print("SYNCING LIRIK...");

  tft.setCursor(15, 75);
  tft.print("Saving Slot: ");
  tft.print(slot);

  // Progress Bar (dinamis berdasarkan total slot yang di-sync)
  tft.drawRect(15, 95, 98, 10, ST77XX_WHITE);
  int progressW = (slot * 94) / max(total, 1);
  tft.fillRect(17, 97, progressW, 6, ST77XX_CYAN);
}

void hideSyncingUI() {
  // Paksa clear area icon bluetooth sebelum fill screen
  tft.fillRect(60, 0, 7, 10, ST77XX_BLACK);

  tft.fillScreen(ST77XX_BLACK);

  // Clear area icon bluetooth lagi setelah fill screen
  tft.fillRect(60, 0, 7, 10, ST77XX_BLACK);

  tft.setFont(&FreeSans9pt7b);

  // Reset flag sync
  isSyncing = false;

  // Paksa kembali ke menu utama agar tidak tersesat di blackscreen
  posisi = 1;
  on = true; // Pastikan flag tampilan aktif
  extern void drawMainMenu();
  drawMainMenu(); // Gambar ulang menu utama tanpa menunggu tombol
  Serial.println("[UI] Screen recovered after sync");
}
