#define BAT_ADC_PIN 5
#define CHRG_IN 45
#define STBY_IN 14

#ifndef ADC_MAX
#define ADC_MAX     4095.0
#endif
#ifndef VREF
#define VREF        3.3
#endif
#ifndef DIV_RATIO
#define DIV_RATIO   2.0
#endif

#ifndef BAT_FULL
#define BAT_FULL    4.2
#endif
#ifndef BAT_EMPTY
#define BAT_EMPTY   3.0
#endif

#ifndef ADC_GAIN
#define ADC_GAIN    0.991
#endif
#ifndef ADC_OFFSET
#define ADC_OFFSET  0.270
#endif




// bool bacajam;
// int lastPercent = -1;
// int percent;
// uint16_t color;
// #define ADC_RESOLUTION 4096
// #define V_REF 3.3
// #define VOLTAGE_DIVIDER_RATIO 0.5
// #define CORRECTION_FACTOR 1.040
// #define V_MIN 3.5  // 0%
// #define V_MAX 4.2
//   void tampilBattery() {
//     int adcValue = analogRead(pinBatt);
//     float voltage = (adcValue / 4095.0) * 3.3 * 2;
//     float vOut = (adcValue * V_REF) / (ADC_RESOLUTION - 1);
//     float vIn = (vOut / VOLTAGE_DIVIDER_RATIO) * CORRECTION_FACTOR;
//       // Hitung persentase baterai
//   float percentage = (vIn - V_MIN) / (V_MAX - V_MIN) * 100;
//   if (percentage > 100) percentage = 100;
//   if (percentage < 0) percentage = 0;
//   if (75 < percentage){
//     percent = 100;
//     color = ST77XX_GREEN;
//   }
//   else if (50 < percentage <= 75 ) {
//     percent = 75;
//     color = ST77XX_YELLOW;
//   }
//   else if (50 < percentage <=25 ) {
//     percent = 50;
//     color = ST77XX_YELLOW;
//   }

//     else if (percentage <= 25 ) {
//     percent = 25;
//     color = ST77XX_RED;
//   }
//     drawBatteryLevel(BATT_X, BATT_Y, percent, color);
//    bacajam = true;
//    //delay(1000);
// }
// // Gambar outline baterai ukuran kecil (20x10) di posisi (x,y)
// void drawBatteryOutline(int x, int y) {
//   tft.drawRect(x, y, 20, 10, ST77XX_WHITE);        // body
//   tft.drawRect(x + 20, y + 3, 3, 4, ST77XX_WHITE); // kepala
// }

// // Mengisi baterai sesuai persen (0–100), warna sesuai status
// void drawBatteryLevel(int x, int y, int percent, uint16_t color) {
//   int levelWidth = map(percent, 0, 100, 0, 18); // max 18 pixel
//   tft.fillRect(x + 1, y + 1, 18, 8, ST77XX_BLACK); // bersihkan isi
//   tft.fillRect(x + 1, y + 1, levelWidth, 8, color); // isi level
// }


// #define ADC_RESOLUTION 4096
// #define V_REF 3.3
// #define VOLTAGE_DIVIDER_RATIO 0.5
// #define CORRECTION_FACTOR 1.040
// #define V_MIN 3.5  // 0%
// #define V_MAX 4.2
// void tampilBattery(){
//   // Baca nilai ADC
//   int adcValue = analogRead(pinBatt);
//   float vOut = (adcValue * V_REF) / (ADC_RESOLUTION - 1);
//   float vIn = (vOut / VOLTAGE_DIVIDER_RATIO) * CORRECTION_FACTOR;
  
//   // Hitung persentase baterai
//   float percentage = (vIn - V_MIN) / (V_MAX - V_MIN) * 100;
//   if (percentage > 100) percentage = 100;
//   if (percentage < 0) percentage = 0;

//   // Tampilkan di Serial Monitor
//   Serial.print("ADC Value: ");
//   Serial.print(adcValue);
//   Serial.print(" | Vout (V): ");
//   Serial.print(vOut, 2);
//   Serial.print(" | Tegangan Baterai (V): ");
//   Serial.print(vIn, 2);
//   Serial.print(" | Persentase: ");
//   Serial.print(percentage, 1);
//   Serial.println("%");

//   // Gambar indikator baterai di TFT
//   drawBatteryIndicator(percentage);
  
//   delay(1000); 

// }

// void drawBatteryIndicator(float percentage) {
//   // Posisi ikon baterai (pojok kanan atas)
//   int x = tft.width() - 28;  // Mulai dari kanan
//   int y = 5;  // Atas
//   int width = 20;  // Lebar ikon baterai
//   int height = 10;  // Tinggi ikon baterai

//   // Gambar bingkai baterai
//   tft.drawRect(x, y, width, height, ST77XX_WHITE);  // Bingkai luar
//   tft.fillRect(x + width, y + 2, 2, height - 4, ST77XX_WHITE);  // Ujung positif

//   // Hitung jumlah blok berdasarkan persentase
//   int fillBlocks = 0;
//   if (percentage >= 90) fillBlocks = 4;
//   else if (percentage >= 75) fillBlocks = 3;
//   else if (percentage >= 50) fillBlocks = 2;
//   else if (percentage >= 25) fillBlocks = 1;
//   else if (percentage > 0) fillBlocks = 0;

//   // Gambar blok pengisian
//   int blockWidth = (width - 4) / 4;  // Lebar setiap blok (4 blok total)
//   for (int i = 0; i < fillBlocks; i++) {
//     tft.fillRect(x + 2 + (i * blockWidth), y + 2, blockWidth - 1, height - 4, ST77XX_GREEN);
//  }}
