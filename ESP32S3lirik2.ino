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

const char *deret1[] = {"DERET 1",   "1. SABUN",  "2. KUDA",    "3. DINGIN",
                        "4. BANYAK", "5. GULA",   "6. PIPI",    "7. BESAR",
                        "8. ENAK",   "9. LIDAH",  "10. KEMBAR", "11. UMUR",
                        "12. SALON", "13. TIKUS", "14. PANAH",  "15. BECAK",
                        "16. NASI",  "17. ILMU",  "18. KAMAR",  "19. TELOR",
                        "20. TEMPAT"};

const char *deret2[] = {"DERET 2",   "1. WALI",   "2. HAKIM",  "3. PISTOL",
                        "4. KORBAN", "5. DOSA",   "6. BELI",   "7. MEDAN",
                        "8. KUMAN",  "9. NAIK",   "10. ADIK",  "11. IBU",
                        "12. TUGAS", "13. JARUM", "14. SALEP", "15. KABAR",
                        "16. TOMAT", "17. KAPUR", "18. ANGIN", "19. ENCER",
                        "20. MUSUH"};

const char *deret3[] = {"DERET 3",    "1. TULI",    "2. PADI",   "3. KELAS",
                        "4. RAMBUT",  "5. NYAMUK",  "6. GARAM",  "7. BIDAN",
                        "8. BUMI",    "9. KERAS",   "10. NIKAH", "11. OBAT",
                        "12. KARCIS", "13. DALANG", "14. MESIN", "15. KUPON",
                        "16. TAHUN",  "17. RESEP",  "18. BUKU",  "19. MATA",
                        "20. LILIN"};

const char *deret4[] = {"DERET 4",   "1. SAYANG",  "2. KAMPUS", "3. HARI ",
                        "4. OBRAL",  "5. KENAL",   "6. HAMIL",  "7. KITAB",
                        "8. GANTI",  "9. SAPI",    "10. JERUK", "11. RINDU",
                        "12. HANTU", "13. MADU",   "14. SEMIR", "15. SAKIT",
                        "16. LOMBA", "17. PENCAK", "18. BATUK", "19. DEBU",
                        "20. BAKMI"};

const char *deret5[] = {"DERET 5",    "1. ANAK",    "2. DARAH",   "3. USUL",
                        "4. TEMBAK",  "5. MINUM",   "6. API",     "7. BULAN",
                        "8. KILAT",   "9. BERSIH",  "10. KUNCI",  "11. SEDAP",
                        "12. PASAR",  "13. DOKTER", "14. BETON",  "15. MULUT",
                        "16. PAGI",   "17. AKAL",   "18. MISKIN", "19. BARU",
                        "20. KENYANG"};

const char *deret6[] = {"DERET 6",   "1. IMAN",   "2. POLA",     "3. BUKIT",
                        "4. LIBUR",  "5. GADIS",  "6. DAPUR",    "7. JALAN",
                        "8. PENDEK", "9. CAMBUK", "10. KEMBANG", "11. HALUS",
                        "12. MUMI",  "13. SEMUT", "14. KIRI",    "15. OTAK",
                        "16. PESTA", "17. RUKUN", "18. NASIB",   "19. TANAH",
                        "20. AYAM"};

const char *deret7[] = {"DERET 7",    "1. SUNTIK", "2. BARU",    "3. NYAWA",
                        "4. KECAP",   "5. BOLA",   "6. MAKAN",   "7. MURID",
                        "8. SAMPAH",  "9. NENEK",  "10. LEHER",  "11. ASIN",
                        "12. KABEL",  "13. SOAL",  "14. KAIN",   "15. TIDUR",
                        "16. BAIK",   "17. GURU",  "18. RUMPUT", "19. DIAM",
                        "20. PLASTIK"};

const char *deret8[] = {"DERET 8",    "1. TAKSI",  "2. PERUT",    "3. NONA",
                        "4. PISANG",  "5. HUKUM",  "6. MEJA",     "7. BADAN",
                        "8. LAMPU",   "9. GAMBAR", "10. LISTRIK", "11. UMUM",
                        "12. PENSIL", "13. BUAH",  "14. CINA",    "15. KOREK",
                        "16. BANTAL", "17. MANDI", "18. BAKUL",   "19. KURSI",
                        "20. TEKAD"};

const char *deret9[] = {"DERET 9",    "1. HATI",    "2. KOLAM",    "3. BUTA",
                        "4. YAKIN",   "5. GEMUK",   "6. DINAS",    "7. BUDI",
                        "8. LUPA",    "9. KERIS",   "10. KOPI",    "11. AMAL",
                        "12. TAMU",   "13. LEMBUR", "14. SANDANG", "15. KECIL",
                        "16. BANJIR", "17. PANAS",  "18. MURAH",   "19. TUAN"};

const char *deret10[] = {"DERET 10",  "1. TEMPO",  "2. PINTU",    "3. HOTEL",
                         "4. MINYAK", "5. BASAH",  "6. MODAL",    "7. BERAS",
                         "8. DUKUN",  "9. KULIT",  "10. BATIK",   "11. IKAN",
                         "12. DESA",  "13. AIR",   "14. KAMPUNG", "15. LINTAH",
                         "16. MACAN", "17. SUMUR", "18. BENSIN",  "19. PERAK",
                         "20. LAGU"};

const int totalMessages = sizeof(deret1) / sizeof(deret1[0]);
int currentIndex = 0;
unsigned long lastChange = 0;
const unsigned long interval = 8000; // 8.5 detik

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

Word words1[] = {
    {0, "DERET 1"},        {13000, "1. SABUN"},   {20000, "2. KUDA"},
    {26000, "3. DINGIN"},  {32000, "4. BANYAK"},  {39000, "5. GULA"},
    {45000, "6. PIPI"},    {51000, "7. BESAR"},   {58000, "8. ENAK"},
    {64000, "9. LIDAH"},   {71000, "10. KEMBAR"}, {77000, "11. UMUR"},
    {83000, "12. SALON"},  {89000, "13. TIKUS"},  {96000, "14. PANAH"},
    {103000, "15. BECAK"}, {109000, "16. NASI"},  {115000, "17. ILMU"},
    {121000, "18. KAMAR"}, {127000, "19. TELOR"}, {134000, "20. TEMPAT"}};

Word words2[] = {
    {0, "DERET 2"},        {12000, "1. WALI"},    {19000, "2. HAKIM"},
    {25000, "3. PISTOL"},  {31000, "4. KORBAN"},  {37000, "5. DOSA"},
    {44000, "6. BELI"},    {51000, "7. MEDAN"},   {58000, "8. KUMAN"},
    {64000, "9. NAIK"},    {71000, "10. ADIK"},   {79000, "11. IBU"},
    {86000, "12. TUGAS"},  {92000, "13. JARUM"},  {99000, "14. SALEP"},
    {106000, "15. KABAR"}, {113000, "16. TOMAT"}, {120000, "17. KAPUR"},
    {127000, "18. ANGIN"}, {134000, "19. ENCER"}, {141000, "20. MUSUH"}};

Word words3[] = {
    {4000, "DERET 3"},     {10000, "1. TULI"},    {17000, "2. PADI"},
    {24000, "3. KELAS"},   {31000, "4. RAMBUT"},  {38000, "5. NYAMUK"},
    {46000, "6. GARAM"},   {53000, "7. BIDAN"},   {61000, "8. BUMI"},
    {68000, "9. KERAS"},   {75000, "10. NIKAH"},  {82000, "11. OBAT"},
    {89000, "12. KARCIS"}, {97000, "13. DALANG"}, {104000, "14. MESIN"},
    {111000, "15. KUPON"}, {119000, "16. TAHUN"}, {125000, "17. RESEP"},
    {132000, "18. BUKU"},  {140000, "19. MATA"},  {147000, "20. LILIN"}};

Word words4[] = {
    {5000, "DERET 4"},     {11000, "1. SAYANG"},  {18000, "2. KAMPUS"},
    {25000, "3. HARI"},    {33000, "4. OBRAL"},   {41000, "5. KENAL"},
    {48000, "6. HAMIL"},   {56000, "7. KITAB"},   {63000, "8. GANTI"},
    {70000, "9. SAPI"},    {77000, "10. JERUK"},  {84000, "11. RINDU"},
    {91000, "12. HANTU"},  {98000, "13. MADU"},   {105000, "14. SEMIR"},
    {112000, "15. SAKIT"}, {118000, "16. LOMBA"}, {125000, "17. PENCAK"},
    {131000, "18. BATUK"}, {138000, "19. DEBU"},  {145000, "20. BAKMI"}};

Word words5[] = {
    {4000, "DERET 5"},      {10000, "1. ANAK"},    {16000, "2. DARAH"},
    {24000, "3. USUL"},     {30000, "4. TEMBAK"},  {37000, "5. MINUM"},
    {43000, "6. API"},      {50000, "7. BULAN"},   {57000, "8. KILAT"},
    {64000, "9. BERSIH"},   {72000, "10. KUNCI"},  {79000, "11. SEDAP"},
    {85000, "12. PASAR"},   {93000, "13. DOKTER"}, {100000, "14. BETON"},
    {107000, "15. MULUT"},  {114000, "16. PAGI"},  {121000, "17. AKAL"},
    {128000, "18. MISKIN"}, {135000, "19. BARU"},  {141000, "20. KENYANG"}};

Word words6[] = {
    {5000, "DERET 6"},     {11000, "1. IMAN"},     {18000, "2. POLA"},
    {25000, "3. BUKIT"},   {32000, "4. LIBUR"},    {40000, "5. GADIS"},
    {47000, "6. DAPUR"},   {56000, "7. JALAN"},    {62000, "8. PENDEK"},
    {70000, "9. CAMBUK"},  {78000, "10. KEMBANG"}, {85000, "11. HALUS"},
    {92000, "12. MUMI"},   {100000, "13. SEMUT"},  {107000, "14. KIRI"},
    {115000, "15. OTAK"},  {122000, "16. PESTA"},  {130000, "17. RUKUN"},
    {138000, "18. NASIB"}, {146000, "19. TANAH"},  {153000, "20. AYAM"}};

Word words7[] = {
    {4000, "DERET 7"},      {9000, "1. SUNTIK"},  {17000, "2. BARU"},
    {24000, "3. NYAWA"},    {32000, "4. KECAP"},  {38000, "5. BOLA"},
    {45000, "6. MAKAN"},    {55000, "7. MURID"},  {61000, "8. SAMPAH"},
    {69000, "9. NENEK"},    {76000, "10. LEHER"}, {83000, "11. ASIN"},
    {91000, "12. KABEL"},   {99000, "13. SOAL"},  {106000, "14. KAIN"},
    {113000, "15. TIDUR"},  {120000, "16. BAIK"}, {128000, "17. GURU"},
    {135000, "18. RUMPUT"}, {143000, "19. DIAM"}, {150000, "20. PLASTIK"}};

Word words8[] = {
    {5000, "DERET 8"},      {12000, "1. TAKSI"},    {19000, "2. PERUT"},
    {26000, "3. NONA"},     {35000, "4. PISANG"},   {43000, "5. HUKUM"},
    {52000, "6. MEJA"},     {60000, "7. BADAN"},    {68000, "8. LAMPU"},
    {77000, "9. GAMBAR"},   {85000, "10. LISTRIK"}, {92000, "11. UMUM"},
    {100000, "12. PENSIL"}, {107000, "13. BUAH"},   {115000, "14. CINA"},
    {123000, "15. KOREK"},  {130000, "16. BANTAL"}, {138000, "17. MANDI"},
    {145000, "18. BAKUL"},  {152000, "19. KURSI"},  {158000, "20. TEKAD"}};

Word words9[] = {
    {5000, "DERET 9"},     {12000, "1. HATI"},     {19000, "2. KOLAM"},
    {27000, "3. BUTA"},    {34000, "4. YAKIN"},    {41000, "5. GEMUK"},
    {50000, "6. DINAS"},   {57000, "7. BUDI"},     {64000, "8. LUPA"},
    {72000, "9. KERIS"},   {79000, "10. KOPI"},    {87000, "11. AMAL"},
    {95000, "12. TAMU"},   {102000, "13. LEMBUR"}, {110000, "14. SANDANG"},
    {119000, "15. KECIL"}, {127000, "16. BANJIR"}, {134000, "17. PANAS"},
    {142000, "18. MURAH"}, {152000, "19. TUAN"}};

Word words10[] = {
    {6000, "DERET 10"},     {13000, "1. TEMPO"},   {22000, "2. PINTU"},
    {32000, "3. HOTEL"},    {41000, "4. MINYAK"},  {50000, "5. BASAH"},
    {59000, "6. MODAL"},    {70000, "7. BERAS"},   {80000, "8. DUKUN"},
    {88000, "9. KULIT"},    {98000, "10. BATIK"},  {108000, "11. IKAN"},
    {116000, "12. DESA"},   {125000, "13. AIR"},   {133000, "14. KAMPUNG"},
    {142000, "15. LINTAH"}, {152000, "16. MACAN"}, {159000, "17. SUMUR"},
    {168000, "18. BENSIN"}, {178000, "19. PERAK"}, {186000, "20. LAGU"}};
const int totalWords = sizeof(words) / sizeof(words[0]);

bool running = false;

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
  digitalWrite(buttonNext, LOW);
  pinMode(buttonNext, INPUT);
  pinMode(buttonPause, INPUT);
  pinMode(buttonHome, INPUT);
  pinMode(buttonPrevious, INPUT);
  gpio_pulldown_en(GPIO_NUM_2); // aktifkan internal pull-down
  gpio_pullup_dis(GPIO_NUM_2);  // pastikan pull-up dimatikan
  pinMode(buttonVolup, INPUT);
  pinMode(buttonVoldown, INPUT);
  pinMode(buttonMode, INPUT);
  gpio_pulldown_en(GPIO_NUM_6); // aktifkan internal pull-down
  gpio_pullup_dis(GPIO_NUM_6);  // pastikan pull-up dimatikan
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
    Serial.println(F("Unable to begin DFPlayer: Check wiring or SD card."));
    while (true)
      ;
  }

  // ----Set volume----
  myDFPlayer.volume(loud); // Set volume value (0~30).

  //----Set different EQ----
  myDFPlayer.EQ(DFPLAYER_EQ_NORMAL);

  myDFPlayer.outputDevice(DFPLAYER_DEVICE_SD);
  myDFPlayer.playFolder(1, 1);
  delay(200);
  myDFPlayer.stop();
  tft.setFont(&FreeSans9pt7b); // Atur font
  tft.setTextSize(1);
  readRTC();
  digitalWrite(TrigMic, HIGH);
  digitalWrite(TrigRlyDF, HIGH);
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
  /////////////////////////////////button previous ////////////////////////
  previouse();
  /////////////////////////////////button volume up ////////////////////////
  volume();
  /////////////////////////////////button mode ////////////////////////
  modee();
  // ///////////////////////////////button home ////////////////////////
  home();
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
  currentIndex = 0;
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
  currentIndex = 0;
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

  if (currentWord < 21) {

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

void listderet() {
  if (deret == 1)
    words = words1;
  if (deret == 2)
    words = words2;
  if (deret == 3)
    words = words3;
  if (deret == 4)
    words = words4;
  if (deret == 5)
    words = words5;
  if (deret == 6)
    words = words6;
  if (deret == 7)
    words = words7;
  if (deret == 8)
    words = words8;
  if (deret == 9)
    words = words9;
  if (deret == 10)
    words = words10;
}
