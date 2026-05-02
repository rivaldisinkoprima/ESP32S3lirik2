extern int activeDaretCount;

int p = 1;
void nextp(){
      if (digitalRead(buttonNext) == LOW && millis() - lastButtonTime > DEBOUNCE_MS) {
        lastButtonTime = millis();
        
        if (posisi==1){ 
        pilihan++;
        if (pilihan>=4) pilihan =1;
        menu(pilihan);
       }
      else if(posisi==2){  
            if(isPlaying==true){
            selanjutnya();
            if (mode==1) {myDFPlayer.playFolder(1,deret);}
            if (mode==2) {myDFPlayer.playFolder(2,deret);}
            if (mode==3) {myDFPlayer.playFolder(3,deret);}
            // listderet() akan mengecek LittleFS terlebih dahulu
            listderet();
            if (words == NULL) { isPlaying = false; return; }
            stopCounter();    // reset
            startCounter();   // mulai dari awal
            isPlaying=true;}
            if(isPlaying==false){
            selanjutnya();
            if (mode==1) {myDFPlayer.playFolder(1,deret);}
            if (mode==2) {myDFPlayer.playFolder(2,deret);}
            if (mode==3) {myDFPlayer.playFolder(3,deret);}
             myDFPlayer.pause();
             isPlaying=false;}              
            }
            if (posisi==3){
            myDFPlayer.stop();
            isPlaying = false;
            jam++;
            tft.fillRect(15,40,40,100,ST77XX_BLACK);
            tft.setCursor(15, 88);
            if (jam >=24) jam = 0; 
            tft.setTextSize(2);
            if (jam < 10) tft.print("0");
            tft.print(jam);
            tft.setTextSize(1);
           }     
        
    else if( posisi == 4) {
      myDFPlayer.stop();
      isPlaying = false;
        selectedIndex++;
        if (selectedIndex >= getMenuCount()) {
            selectedIndex = 0;
        }
        page = selectedIndex / itemsPerPage;
        displayMenu();
      }

    else if( posisi == 5) {
      int maxPages = getDeretPageCount(selectedIndex);
      if ((halaman + 1) < maxPages) {
        halaman++;
      } else {
        halaman = 0;
      }
      // Gunakan fungsi generik
      displayDeretGeneric(selectedIndex, halaman);
      }
      }
    }
    
    