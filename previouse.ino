void previouse(){
      if (digitalRead(buttonPrevious) == HIGH) {
        if (posisi==1){    
        pilihan--;
        if (pilihan<=0) pilihan =3;
        menu(pilihan);
        delay(500);
       }
       else if(posisi==2){
            sebelumnya();
            if(isPlaying==true){
            if (mode==1) {myDFPlayer.playFolder(1,deret);}
            if (mode==2) {myDFPlayer.playFolder(2,deret);}
            if (mode==3) {myDFPlayer.playFolder(3,deret);}
            listderet();
            stopCounter();    // reset
            startCounter();   // mulai dari awal
             isPlaying= true;}
             if(isPlaying==false){
            if (mode==1) {myDFPlayer.playFolder(1,deret);}
            if (mode==2) {myDFPlayer.playFolder(2,deret);}
            if (mode==3) {myDFPlayer.playFolder(3,deret);}
             myDFPlayer.pause();
             isPlaying=false;}
             currentIndex = 0;
            Serial.println("Previous Song..");
            delay(500);             
            }
      else if (posisi==3){
            myDFPlayer.stop();
            isPlaying = false;
            jam--;
            tft.fillRect(15,40,40,100,ST77XX_BLACK);
            tft.setCursor(15, 88);
            if (jam <= -1) jam = 23; 
            tft.setTextSize(2);
            if (jam < 10) tft.print("0");
            tft.print(jam);
            tft.setTextSize(1);
            delay (500);
          } 
      else if (posisi==4){
        myDFPlayer.stop();
        isPlaying = false;
        selectedIndex--;
        if (selectedIndex < 0) {
        selectedIndex = menuCount - 1;
        }
        page = selectedIndex / itemsPerPage;
        displayMenu();
        delay(500);
          }
      else if (posisi==5){
      //  myDFPlayer.stop();
      //  isPlaying = false;
      if (halaman > 0) halaman--;
      else halaman = 2;
      if (selectedIndex==0)displayderet1(halaman);
      if (selectedIndex==1)displayderet2(halaman);
      if (selectedIndex==2) displayderet3(halaman);
      if (selectedIndex==3) displayderet4(halaman);
      if (selectedIndex==4) displayderet5(halaman);
      if (selectedIndex==5) displayderet6(halaman);
      if (selectedIndex==6) displayderet7(halaman);
      if (selectedIndex==7) displayderet8(halaman);
      if (selectedIndex==8) displayderet9(halaman);
      if (selectedIndex==9) displayderet10(halaman);
      delay(500);
       }
    }   
    }