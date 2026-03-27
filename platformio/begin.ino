
#include "bitmapsLarge.h"
#include "whisper_logo.h"
#include "elitech_logo.h"

void begin(){
    tft.fillScreen(ST7735_WHITE);
    int j =50, i = 128, ro, co, buffidx2=0;
    for (ro= 55; ro<55+j; ro++) { // For each scanline...
    for (co=0; co<i; co++) { // For each pixel...
      //To read from Flash Memory, pgm_read_XXX is required.
      //Since image is stored as uint16_t, pgm_read_word is used as it uses 16bit address
      tft.drawPixel(co, ro, pgm_read_word(elitech_logo + buffidx2));
      buffidx2++;
    } // end pixel
  }
  delay(2000);

	tft.fillScreen(ST7735_BLACK);


  int y = 124,x = 128, r, c, buffidx1=0;
  for (r= 0; r<y; r++) { // For each scanline...
    for (c=0; c<x; c++) { // For each pixel...
      //To read from Flash Memory, pgm_read_XXX is required.
      //Since image is stored as uint16_t, pgm_read_word is used as it uses 16bit address
      tft.drawPixel(c, r, pgm_read_word(whisper_logo + buffidx1));
      buffidx1++;
    } // end pixel
  }
  delay(1500);
//Case 2: Multi Colored Images/Icons
  int h = 156,w = 128, row, col, buffidx=0;
  for (row= 0; row<h; row++) { // For each scanline...
    for (col=0; col<w; col++) { // For each pixel...
      //To read from Flash Memory, pgm_read_XXX is required.
      //Since image is stored as uint16_t, pgm_read_word is used as it uses 16bit address
      tft.drawPixel(col, row, pgm_read_word(menu_interface + buffidx));
      buffidx++;
    } // end pixel
  }
menu(pilihan);
delay (500);
  on = true;
}