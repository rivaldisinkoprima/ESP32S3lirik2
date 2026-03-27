#define ADC_MAX     4095.0
#define VREF        3.3

#define BAT_FULL    4.1
#define BAT_EMPTY   3.2

#define ADC_GAIN    0.991
#define ADC_OFFSET  0.270

float lastStableVoltage = 0;
int stablePercent = -1;

// ================= DRAW FUNCTIONS =================
void drawBatteryMini() {

  static bool firstRead = true;
  static float smoothVoltage = 0;

  float vBat = readBatteryVoltage();

  if (firstRead) {
    smoothVoltage = vBat;        // langsung pakai nilai asli
    firstRead = false;
  } else {
    smoothVoltage = (smoothVoltage * 0.99) + (vBat * 0.01);
  }

  int percent = batteryPercent(smoothVoltage);

    if ((lastState == CHARGING) && (currentState == NOT_CHARGING)){
      stablePercent = percent;
      drawBatteryMiniWithPercent(stablePercent);
  }
  if (percent != stablePercent) {
    stablePercent = percent;
    drawBatteryMiniWithPercent(stablePercent);
  }
}
// void drawBatteryMini() {
//   static bool firstRead = true;
//   static float smoothVoltage = 0;
//   int newPercent = batteryPercent(smoothVoltage);

//   float vBat = readBatteryVoltage();

//   // FIX: agar tidak naik pelan di awal
//   if (firstRead) {
//     smoothVoltage = vBat;
//     firstRead = false;
//   } else {
//     smoothVoltage = (smoothVoltage * 0.99) + (vBat * 0.01);
//   }

//   int percent = batteryPercent(smoothVoltage);
  
//   if ((lastState == CHARGING) && (currentState == NOT_CHARGING)){
//       drawBatteryMiniWithPercent(percent);
//       last_percent = percent;
//   }

// if (firstRead) {
//     stablePercent = newPercent;
//     drawBatteryMiniWithPercent(stablePercent);
//     firstRead = false;
// }
// else if (newPercent != stablePercent) {
//     stablePercent = newPercent;
//     drawBatteryMiniWithPercent(stablePercent);
// }
// }

// ================= DETECT CHARGER STATE =================
ChargerState getChargerState() {
  bool chrg = digitalRead(PIN_CHRG);
  bool stby = digitalRead(PIN_STBY);

  if (!chrg && stby) return CHARGING;
  if (chrg && !stby) return FULL;
  return NOT_CHARGING;
}

// ================= DRAW SCREEN (ONLY WHEN CHANGED) =================
void drawBatteryScreen(ChargerState state) {
  switch (state) {

    case CHARGING:
    drawBatteryMiniCharging();
      break;

    case FULL:
      drawBatteryFull();                  // hijau penuh
      break;

    case NOT_CHARGING:
      drawBatteryMini();                 // kosong
      break;
  }
}

// ================= ADC AVERAGING =================
float readBatteryVoltage() {
  long sum = 0;
  for (int i = 0; i < 30; i++) {
    sum += analogRead(BAT_ADC_PIN);
    //delay(2);
  }
  float adcAvg = sum / 30.0;
  float vAdc = (adcAvg / ADC_MAX) * VREF;
  float vBat = (vAdc * 2.0 * ADC_GAIN) + ADC_OFFSET;
  return vBat;
}

// ================= BATTERY PERCENT ==============
int batteryPercent(float voltage) {
  if (voltage >= BAT_FULL) return 100;
  if (voltage <= BAT_EMPTY) return 0;

  return (int)((voltage - BAT_EMPTY) /
               (BAT_FULL - BAT_EMPTY) * 100);
}

// ================= TFT DRAW =====================

void drawBatteryMiniWithPercent(int percent) {
  percent = constrain(percent, 0, 100);

  int iconW = 16;
  int iconH = 7;

  int xIcon = tft.width() - 20; // posisi ikon (kanan)
  int yIcon = 3;

  int xText = xIcon - 22;       // posisi teks di kiri ikon
  int yText = 2;

  // ====== CLEAR AREA ======
  // Bersihkan area teks + ikon saja (anti flicker)
  tft.fillRect(xText, yText, 40, 12, ST7735_BLACK);

  // ====== DRAW TEXT ======
  tft.setFont(NULL);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_WHITE);
  tft.setCursor(xText, yText);
  tft.print(percent);
  tft.print("%");
  tft.setFont(&FreeSans9pt7b); // Atur font

  // ====== DRAW BATTERY OUTLINE ======
  tft.drawRect(xIcon, yIcon, iconW, iconH, ST7735_WHITE);
  tft.fillRect(xIcon + iconW, yIcon + 2, 2, iconH - 4, ST7735_WHITE); // kutub

  // ====== FILL BATTERY ======
  int fillW = map(percent, 0, 100, 0, iconW - 2);

  uint16_t color = ST7735_GREEN;
  if (percent <= 20) color = ST7735_RED;
  else if (percent <= 50) color = ST7735_YELLOW;

  if (fillW > 0) {
    tft.fillRect(xIcon + 1, yIcon + 1, fillW, iconH - 2, color);
  }
}

void drawBatteryFull(){
  int iconW = 16;
  int iconH = 7;

  int xIcon = tft.width() - 26; // battery agak ke kiri
  int yIcon = 3;

  int xClear = xIcon - 26;
  int yClear = 2;

  // ===== CLEAR AREA =====
  tft.fillRect(xClear, yClear, 60, 12, ST7735_BLACK);

  // ===== BATTERY OUTLINE =====
  tft.drawRect(xIcon, yIcon, iconW, iconH, ST7735_WHITE);
  tft.fillRect(xIcon + iconW, yIcon + 2, 2, iconH - 4, ST7735_WHITE); // kutub
  tft.fillRect(xIcon + 1, yIcon + 1, iconW - 2, iconH - 2, ST7735_GREEN);

  // ===== PETIR DI SAMPING KANAN =====
  int px = xIcon + iconW + 4;  // jarak dari battery
  int py = yIcon + 1;

  tft.drawLine(px + 2, py,     px,     py + 3, ST7735_YELLOW);
  tft.drawLine(px,     py + 3, px + 3, py + 3, ST7735_YELLOW);
  tft.drawLine(px + 3, py + 3, px + 1, py + 6, ST7735_YELLOW);
}

void drawBatteryMiniCharging() {
  int iconW = 16;
  int iconH = 7;

  int xIcon = tft.width() - 26; // battery agak ke kiri
  int yIcon = 3;

  int xClear = xIcon - 26;
  int yClear = 2;

  // ===== CLEAR AREA =====
  tft.fillRect(xClear, yClear, 60, 12, ST7735_BLACK);

  // ===== BATTERY OUTLINE =====
  tft.drawRect(xIcon, yIcon, iconW, iconH, ST7735_WHITE);
  tft.fillRect(xIcon + iconW, yIcon + 2, 2, iconH - 4, ST7735_WHITE); // kutub

  // ===== PETIR DI SAMPING KANAN =====
  int px = xIcon + iconW + 4;  // jarak dari battery
  int py = yIcon + 1;

  tft.drawLine(px + 2, py,     px,     py + 3, ST7735_YELLOW);
  tft.drawLine(px,     py + 3, px + 3, py + 3, ST7735_YELLOW);
  tft.drawLine(px + 3, py + 3, px + 1, py + 6, ST7735_YELLOW);
}

void bat_cas(){
  if (millis() - lastBatteryUpdate >= 500) {
    lastBatteryUpdate = millis();

    currentState = getChargerState();

    if (currentState != lastState) {
      drawBatteryScreen(currentState);
      lastState = currentState;
    }

    if (currentState == NOT_CHARGING) {
      drawBatteryMini();
    }
  }
}

void bat_cas_move(){
    currentState = getChargerState();

    if (currentState == CHARGING) {
      drawBatteryMiniCharging();
    }
    if (currentState == NOT_CHARGING) {
      drawBatteryMiniWithPercent(stablePercent);
    }
}