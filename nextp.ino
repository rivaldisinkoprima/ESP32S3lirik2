int p = 1;
void nextp(){
      if (digitalRead(buttonNext) == HIGH) {
        if (posisi==1){ 
        //myDFPlayer.stop();
        //isPlaying = false;     
        pilihan++;
        if (pilihan>=4) pilihan =1;
        menu(pilihan);
        delay(300);
       }
      else if(posisi==2){  
            if(isPlaying==true){
            selanjutnya();
            if (mode==1) {myDFPlayer.playFolder(1,deret);}
            if (mode==2) {myDFPlayer.playFolder(2,deret);}
            if (mode==3) {myDFPlayer.playFolder(3,deret);}
            if (deret==1)words = words1;
            if (deret==2)words = words2;
            listderet();
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
            delay(500);
            }
            if (posisi==3){
            myDFPlayer.stop();
            isPlaying = false;
            jam++;
            tft.fillRect(15,40,40,100,ST77XX_BLACK);
            tft.setCursor(15, 88);
            //a_menit= l_minute + menit;
            //if (a_menit >=60) {menit = 0; a_menit = 0; }
            //if (a_menit < 10) tft.print("0");
            if (jam >=24) jam = 0; 
            tft.setTextSize(2);
            if (jam < 10) tft.print("0");
            tft.print(jam);
            tft.setTextSize(1);
            delay (500);
          }     
        
    else if( posisi == 4) {
      myDFPlayer.stop();
      isPlaying = false;
        selectedIndex++;
        if (selectedIndex >= menuCount) {
            selectedIndex = 0;
        }
        page = selectedIndex / itemsPerPage;
        displayMenu();
        delay(200);
      }

    else if( posisi == 5) {
      // myDFPlayer.stop();
      // isPlaying = false;
      if ((halaman + 1) * kataPerHalaman < totalKata) {
      halaman++;}
      else halaman = 0;
      if (selectedIndex==0) displayderet1(halaman);
      if (selectedIndex==1) displayderet2(halaman);
      if (selectedIndex==2) displayderet3(halaman);
      if (selectedIndex==3) displayderet4(halaman);
      if (selectedIndex==4) displayderet5(halaman);
      if (selectedIndex==5) displayderet6(halaman);
      if (selectedIndex==6) displayderet7(halaman);
      if (selectedIndex==7) displayderet8(halaman);
      if (selectedIndex==8) displayderet9(halaman);
      if (selectedIndex==9) displayderet10(halaman);
      delay(300);
      }
      }
    }
    
    