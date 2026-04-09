#include "bitmapsLarge.h"

// Fungsi Mandiri untuk Menggambar Menu Utama (Tanpa Cek Tombol)
void drawMainMenu() {
  tft.drawRGBBitmap(0, 0, menu_interface, 128, 156);
  tft.fillRect(0, 156, 128, 4, ST77XX_BLACK);
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