void readRTC() {
  Wire.beginTransmission(DS3231_ADDRESS);
  Wire.write(0x00);  // Memulai dari register 0x00 (detik)
  Wire.endTransmission();
  Wire.requestFrom(DS3231_ADDRESS, 7);
  
  byte second = bcdToDec(Wire.read() & 0x7F);
  byte minute = bcdToDec(Wire.read());
  byte hour = bcdToDec(Wire.read() & 0x3F);  // Mask jam 24 jam format
  byte day = bcdToDec(Wire.read());
  byte date = bcdToDec(Wire.read());
  byte month = bcdToDec(Wire.read() & 0x1F);
  byte year = bcdToDec(Wire.read());

  if ((minute != l_minute) || (hour != l_hour)) {
  tft.setFont(NULL);
  tft.setTextSize(1);
  tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);  // background overwrite
  tft.setCursor(5,2);
  if (hour < 10) tft.print("0");
  tft.print(hour);
  tft.print(":");
  if (minute < 10) tft.print("0");
  tft.print(minute);
  tft.setFont(&FreeSans9pt7b);
} 
  l_minute = minute;
  l_hour = hour;
}
