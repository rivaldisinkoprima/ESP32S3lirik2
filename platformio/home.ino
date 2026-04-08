#include "bitmapsLarge.h"

// Fungsi Mandiri untuk Menggambar Menu Utama (Tanpa Cek Tombol)
void drawMainMenu() {
  tft.fillScreen(ST77XX_BLACK);
  int h = 156, w = 128, row, col, buffidx = 0;
  for (row = 0; row < h; row++) { 
    for (col = 0; col < w; col++) { 
      tft.drawPixel(col, row, pgm_read_word(menu_interface + buffidx));
      buffidx++;
    } 
  }
  tampiljam();
  bat_cas_move();
  menu(pilihan);
}

// Fungsi Original untuk Handle Tombol Home
void home() {
  if (digitalRead(buttonHome) == HIGH) {
    digitalWrite(TrigMic, HIGH);
    myDFPlayer.stop();
    currentWord = 0;
    
    if (posisi == 5) {
      file();
      halaman = 0;
    } else {
      posisi = 1;
      menit = 0;
      drawMainMenu();
      page = 0;
      stopCounter();
      selectedIndex = 0;
    }
    delay(200);
  }
}