  #include "bitmapsLarge.h"

void home(){
  if(digitalRead(buttonHome)==HIGH){
      digitalWrite(TrigMic,HIGH);
      myDFPlayer.stop();
      //isPlaying = true;
      //deret = 1;
      currentIndex = 0;
      if (posisi == 5){
      file();
      halaman=0;} 
      else {
      posisi = 1;
      menit = 0;
      jam = 0;
      tft.fillScreen(ST77XX_BLACK);
      int h = 156,w = 128, row, col, buffidx=0;
      for (row= 0; row<h; row++) { // For each scanline...
      for (col=0; col<w; col++) { // For each pixel...
      //To read from Flash Memory, pgm_read_XXX is required.
      //Since image is stored as uint16_t, pgm_read_word is used as it uses 16bit address
      tft.drawPixel(col, row, pgm_read_word(menu_interface + buffidx));
      buffidx++;
    } // end pixel
  }

      tampiljam();
      //drawBatteryMiniWithPercent(last_percent);
      bat_cas_move();
      menu(pilihan);
      page=0;
      stopCounter();
      selectedIndex = 0;}
      delay(200);
      }
}