
#include "bitmapsLarge.h"
#include "whisper_logo.h"
#include "elitech_logo.h"

void begin(){
    tft.fillScreen(ST7735_WHITE);
    tft.drawRGBBitmap(0, 55, elitech_logo, 128, 50);
    esp_task_wdt_reset();
    delay(2000);
    esp_task_wdt_reset();

    tft.fillScreen(ST7735_BLACK);
    tft.drawRGBBitmap(0, 0, whisper_logo, 128, 124);
    esp_task_wdt_reset();
    delay(1500);
    esp_task_wdt_reset();

    tft.drawRGBBitmap(0, 0, menu_interface, 128, 156);
    menu(pilihan);
    tampiljam(); // ★ Tampilkan jam yang sudah direadRTC() ke menu utama
    esp_task_wdt_reset();
    delay(500);
    esp_task_wdt_reset();
    on = true;
}