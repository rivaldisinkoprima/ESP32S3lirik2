      void volume(){
       
      if(digitalRead(buttonVolup)==HIGH){
        if(posisi==2&&(isPlaying ||isPlaying == false)){
          loud++;
          if(loud>=24) loud = 23;
          myDFPlayer.volume(loud);
          t_loud = t_loud+5;
          if(t_loud==5) t_loud = 35;
          if(t_loud>=90) t_loud = 85;
          //if(t_loud<=1) t_loud = 35;
          //myDFPlayer.volumeUp();
          tft.fillRect(28,136,32,14,ST77XX_BLACK);
          tft.setCursor(30,148);
          tft.setTextSize(1);
          tft.println(t_loud);
          //Serial.println(myDFPlayer.readVolume());
          }
          if (posisi==3){
            myDFPlayer.stop();
            isPlaying = false;
            menit++;
            tft.fillRect(64,50,100,100,ST77XX_BLACK);
            tft.setCursor(65, 88);
            if (menit >=60) menit = 0; 
            tft.setTextSize(2);
            if (menit < 10) tft.print("0");
            tft.print(menit);
            tft.setTextSize(1);
          }
          delay(500);
      }
        if(digitalRead(buttonVoldown)==HIGH){
        if(posisi==2&&(isPlaying ||isPlaying == false)){
          loud--;
          if(loud<=12) loud = 0;
          myDFPlayer.volume(loud);
          if (loud==0) loud = 12;
          t_loud = t_loud-5;
          if(t_loud<=34) t_loud = 0;
          //myDFPlayer.volumeDown();
          tft.fillRect(28,136,32,14,ST77XX_BLACK);
          tft.setCursor(30,148);
          tft.setTextSize(1);
          tft.println(t_loud);
          }
        if (posisi==3){
            myDFPlayer.stop();
            isPlaying = true;
            menit--;
            tft.fillRect(64,50,100,100,ST77XX_BLACK);
            tft.setCursor(65, 88);
            //a_menit= l_minute + menit;
            //if (a_menit >=60) {menit = 0; a_menit = 0; }
            //if (a_menit < 10) tft.print("0");
            if (menit < 0) menit = 59; 
            tft.setTextSize(2);
            if (menit < 10) tft.print("0");
            tft.print(menit);
            tft.setTextSize(1);
          }
          delay(500);
      }
      //Serial.println(myDFPlayer.readVolume());
      }