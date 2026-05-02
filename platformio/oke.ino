
void oke() {
    if (digitalRead(buttonPause) == LOW && millis() - lastButtonTime > DEBOUNCE_MS) {
        lastButtonTime = millis();
        
        if (posisi == 1) {
            if (pilihan == 1) {
                myDFPlayer.stop();
                isPlaying = true;
                tft.fillScreen(ST77XX_BLACK);
                screening();
            }
            if (pilihan == 2) {
                myDFPlayer.stop();
                isPlaying = false;
                tft.fillScreen(ST77XX_BLACK);
                file();
            }
            if (pilihan == 3) {
                tft.fillScreen(ST77XX_BLACK);
                tampiljam();
                tft.setCursor(27, 34);
                tft.print("Atur Jam");
                aturjam();
            }
            bat_cas_move();
        }
        
        if (posisi == 2) {
            if (isPlaying) {
                digitalWrite(TrigMic, HIGH);
                myDFPlayer.pause();
                isPlaying = false;
                pauseCounter();
                Serial.println("Paused..");
                tft.fillRect(57, 107, 5, 18, ST77XX_BLACK);
                tft.fillRect(68, 107, 5, 18, ST77XX_BLACK);
                tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
            } else {
                tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
                tft.fillRect(57, 107, 5, 18, ST77XX_WHITE);
                tft.fillRect(68, 107, 5, 18, ST77XX_WHITE);
                isPlaying = true;
                digitalWrite(TrigMic, LOW);
                myDFPlayer.start();
                listderet();
                if (words == NULL) {
                    // Slot kosong — batalkan play, cegah crash
                    isPlaying = false;
                    stopCounter();
                    tft.fillRect(57, 107, 5, 18, ST77XX_BLACK);
                    tft.fillRect(68, 107, 5, 18, ST77XX_BLACK);
                    tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
                    return;
                }
                if (deret == lastDeret) startCounter();
                else {
                    stopCounter();
                    startCounter();
                }
            }
        }

        if (posisi == 4) {
            if (displaymenu == 1) {  
                displaymenu = 2;
                Serial.println("File dipilih, pindah ke displaymenu = 2");
            } 
            else if (displaymenu == 2) {  
                // Gunakan fungsi generik (selectedIndex = 0-based)
                displayDeretGeneric(selectedIndex, halaman);
            }
        }
    }
}
