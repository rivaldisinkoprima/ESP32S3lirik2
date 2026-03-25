void modee(){
        static byte hourSet, minuteSet;
        if(digitalRead(buttonMode)==HIGH){
        if(posisi==2){
          mode--;
          if(mode<=0)mode=3;
          Serial.println("READ MODE");
          sesion();
          listderet();
          stopCounter();    // reset
          startCounter();   // mulai dari awal
          }
        if (posisi==3){
          myDFPlayer.stop();
          isPlaying = true;
          hourSet = jam % 24;   
          minuteSet = menit % 60;  // Reset ke 0 setelah 59
          Serial.print("Menit diatur ke: "); Serial.println(minuteSet);
          setRTC(hourSet, minuteSet);
          jam = 0; menit = 0;
          tft.fillRect(15,40,100,100,ST77XX_BLACK);
          tft.setCursor(15,88);
          tft.setTextSize(2);
          tft.print("00:00");
          tft.setTextSize(1);
          readRTC();
        }
          delay(200);
      }
}

void setRTC(byte hour, byte minute) {
  Wire.beginTransmission(DS3231_ADDRESS);
  Wire.write(0x00);  // Mulai dari register detik
  Wire.write(decToBcd(0)); // Reset detik ke 0
  Wire.write(decToBcd(minute));
  Wire.write(decToBcd(hour));
  Wire.endTransmission();
}

byte bcdToDec(byte val) {
  return (val / 16 * 10) + (val % 16);
}

byte decToBcd(byte val) {
  return (val / 10 * 16) + (val % 10);
}
