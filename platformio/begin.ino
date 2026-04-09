
#include "bitmapsLarge.h"
#include "whisper_logo.h"
#include "elitech_logo.h"

void begin(){
    tft.fillScreen(ST7735_WHITE);
    tft.drawRGBBitmap(0, 55, elitech_logo, 128, 50);
    delay(2000);

    tft.fillScreen(ST7735_BLACK);
    tft.drawRGBBitmap(0, 0, whisper_logo, 128, 124);
    delay(1500);

    tft.drawRGBBitmap(0, 0, menu_interface, 128, 156);
    menu(pilihan);
    delay(500);
  on = true;
}