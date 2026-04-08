#include "Fonts/FreeSans9pt7b.h" // Font tambahan
#include "Fonts/Org_01.h"        // Font tambahan
#include "HardwareSerial.h"
#include "RTClib.h"
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


// Deklarasi fungsi UI untuk dipanggil di ble_server.ino
void showSyncingUI(int slot, int total);
void hideSyncingUI();
void drawBTIcon();
bool isSyncing = false; // Flag untuk menandai sedang sync

HardwareSerial mySerial1(1);

#define TFT_CS 13
#define TFT_RST 12
#define TFT_DC 11
#define TFT_MOSI 10
#define TFT_SCK 15

#define PIN_CHRG 45
#define PIN_STBY 48

#define DS3231_ADDRESS 0x68 // Alamat default RTC DS3231

#define BAT_ADC_PIN 5

#define BATT_X 100
#define BATT_Y 3

SPIClass spiTFT(HSPI); // Use default VSPI
Adafruit_ST7735 tft = Adafruit_ST7735(&spiTFT, TFT_CS, TFT_DC, TFT_RST);

static const uint8_t PIN_MP3_TX = 36; // D7
static const uint8_t PIN_MP3_RX = 35; // D6
SoftwareSerial mySoftwareSerial(PIN_MP3_RX, PIN_MP3_TX);

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

enum ChargerState { NOT_CHARGING, CHARGING, FULL };

ChargerState lastState = NOT_CHARGING;
ChargerState currentState;

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
// ---------------------------------------------

void setup() {
  pinMode(TrigMic, OUTPUT);
  pinMode(TrigRlyDF, OUTPUT);
  digitalWrite(TrigMic, LOW);
  digitalWrite(TrigRlyDF, LOW);
  delay(200);
  pinMode(TrigPower, OUTPUT);
  digitalWrite(TrigPower, LOW);
  pinMode(14, INPUT);
  Serial.begin(9600);
  spiTFT.begin(TFT_SCK, -1, TFT_MOSI, TFT_CS);
  tft.initR(INITR_BLACKTAB);
  tft.setRotation(2);
  pinMode(17, OUTPUT);
  digitalWrite(17, HIGH);
  delay(200);
  begin();
  Wire.begin(37, 38);
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

  mySerial1.begin(9600, SERIAL_8N1, 36, 35); // RX=1, TX=2 (Adjust as needed)
  delay(1000);
  Serial.println("Initializing DFPlayer ...");

  if (!myDFPlayer.begin(mySerial1, true, true)) {
    Serial.println(F("DFPlayer tidak ditemukan (Skip untuk testing)"));
    // while (true) ; // Disabled untuk testing tanpa hardware
  } else {
    // ----Set volume----
    myDFPlayer.volume(loud); // Set volume value (0~30).

    //----Set different EQ----
    myDFPlayer.EQ(DFPLAYER_EQ_NORMAL);

    myDFPlayer.outputDevice(DFPLAYER_DEVICE_SD);
    myDFPlayer.playFolder(1, 1);
    delay(200);
    myDFPlayer.stop();
  }
  tft.setFont(&FreeSans9pt7b); // Atur font
  tft.setTextSize(1);
  readRTC();
  digitalWrite(TrigMic, HIGH);
  digitalWrite(TrigRlyDF, HIGH);

  // Initialize LittleFS
  if (initLittleFS()) {
    Serial.println("[SETUP] LittleFS ready for lyrics storage");
    // Debug: show which derets have LittleFS data
    Serial.println("[SETUP] Checking LittleFS deret availability:");
    for (int i = 1; i <= 10; i++) {
      Serial.print("[SETUP]   Deret ");
      Serial.print(i);
      Serial.print(": ");
      Serial.println(deretExistsInLittleFS(i) ? "LittleFS ✓"
                                              : "Hardcoded (default)");
    }
  } else {
    Serial.println(
        "[SETUP] WARNING: LittleFS failed, using hardcoded data only");
  }

  // Initialize BLE Server
  initBLE();

  Serial.println("[SETUP] ========================================");
  Serial.println("[SETUP] System initialization COMPLETE");
  Serial.print("[SETUP] Free heap: ");
  Serial.print(ESP.getFreeHeap());
  Serial.println(" bytes");
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
    vTaskDelay(10 / portTICK_PERIOD_MS); // Mengalah (yield) agar system tidak marah
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
  if (deret >= 11)
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
    deret = 10;
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

  if (!running)
    return; // penting, stop menghentikan counting

  elapsedTime = millis() - startTime;

  if (currentWord < loadedWordCount) {

    if (elapsedTime >= words[currentWord].time) {
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
  if (isSyncing) return;
  
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

  // Progress Bar
  tft.drawRect(15, 95, 98, 10, ST77XX_WHITE);
  int progressW = (slot * 94) / 10; // Asumsi 10 slot total
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
  on = true;  // Pastikan flag tampilan aktif
  extern void drawMainMenu();
  drawMainMenu(); // Gambar ulang menu utama tanpa menunggu tombol
  Serial.println("[UI] Screen recovered after sync");
}
