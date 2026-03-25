
void oke() {
    if (digitalRead(buttonPause) == HIGH) { // Jika tombol ditekan
        if (posisi == 1) {
            if (pilihan == 1) {
                myDFPlayer.stop();
                isPlaying = true;
                tft.fillScreen(ST77XX_BLACK);
                screening();
            }
            if (pilihan == 2) {  // Masuk ke daftar file
                myDFPlayer.stop();
                isPlaying = false;
                tft.fillScreen(ST77XX_BLACK);
                file();  // Pastikan fungsi file() hanya menampilkan daftar file
            }
            if (pilihan == 3) {
                tft.fillScreen(ST77XX_BLACK);
                tampiljam();
                tft.setCursor(27, 34);
                tft.print("Atur Jam");
                aturjam();
            }
          //drawBatteryMiniWithPercent(last_percent);
          bat_cas_move();
        }
        if (posisi==2){
        if (isPlaying) {
            digitalWrite(TrigMic,HIGH);
            myDFPlayer.pause();
            isPlaying = false;
            pauseCounter();
            Serial.println("Paused..");
            tft.fillRect(57, 107,5,18,ST77XX_BLACK);
            tft.fillRect(68, 107,5,18,ST77XX_BLACK);
            tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
            } 
            else if (isPlaying==false){
            tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
            tft.fillRect(57, 107,5,18,ST77XX_WHITE);
            tft.fillRect(68, 107,5,18,ST77XX_WHITE);
            isPlaying = true;
            digitalWrite(TrigMic,LOW);
            myDFPlayer.start();
            listderet();
            if (deret == lastDeret) startCounter();
            else {
            stopCounter();    // reset
            startCounter();   // mulai dari awal
            }}}


        if (posisi == 4) {  // Menangani navigasi di daftar file
            if (displaymenu == 1) {  
                // Jika masih dalam mode daftar file, tekan "OK" untuk memilih file
                displaymenu = 2;  // Pindah ke mode tampilan file
                Serial.println("File dipilih, pindah ke displaymenu = 2");
            } 
            else if (displaymenu == 2) {  
                // Jika displaymenu == 2, baru tampilkan isi file
                // myDFPlayer.stop();
                // isPlaying = false;

                switch (selectedIndex) {
                    case 0: displayderet1(halaman); break;
                    case 1: displayderet2(halaman); break;
                    case 2: displayderet3(halaman); break;
                    case 3: displayderet4(halaman); break;
                    case 4: displayderet5(halaman); break;
                    case 5: displayderet6(halaman); break;
                    case 6: displayderet7(halaman); break;
                    case 7: displayderet8(halaman); break;
                    case 8: displayderet9(halaman); break;
                    case 9: displayderet10(halaman); break;
                }
            }
        }

       delay(300);
    }
}
