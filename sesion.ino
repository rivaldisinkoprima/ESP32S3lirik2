  void sesion(){
          tft.fillRect(8, 70, 150, 20, ST77XX_BLACK);
          deret = 1;
          currentIndex = 0;
            if (isPlaying==false){
            if (mode==1) {myDFPlayer.playFolder(1,1);}
            if (mode==2) {myDFPlayer.playFolder(2,1);}
            if (mode==3) {myDFPlayer.playFolder(3,1);}
            myDFPlayer.stop();
            isPlaying=false;}
         else {
            if (mode==1) {myDFPlayer.playFolder(1,1);}
            if (mode==2) {myDFPlayer.playFolder(2,1);}
            if (mode==3) {myDFPlayer.playFolder(3,1);}
         }
          tft.fillRect(70,13,70,22,ST77XX_BLACK);
          tft.setCursor(73,35);
          tft.setTextSize(1);
          tft.print("1");
          tft.fillRect(73,38,120,22,ST77XX_BLACK);
          tft.setTextSize(1);
          tft.setCursor(73,55);
          if (mode==1) {tft.print("Kanan");}
          if (mode==2) {tft.print("Kiri");}
          if (mode==3) {tft.print("All");}
          }