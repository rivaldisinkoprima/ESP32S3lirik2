void readRTC() {
  // --- DI-COMMENT UNTUK TESTING ---
  // Wire.beginTransmission(DS3231_ADDRESS);
  // Wire.write(0x00);
  // Wire.endTransmission();
  // Wire.requestFrom(DS3231_ADDRESS, 7);
  // byte second = bcdToDec(Wire.read() & 0x7F);
  // byte minute = bcdToDec(Wire.read());
  // byte hour = bcdToDec(Wire.read() & 0x3F);  
  // byte day = bcdToDec(Wire.read());
  // byte date = bcdToDec(Wire.read());
  // byte month = bcdToDec(Wire.read() & 0x1F);
  // byte year = bcdToDec(Wire.read());

  // l_minute = minute;
  // l_hour = hour;
}
