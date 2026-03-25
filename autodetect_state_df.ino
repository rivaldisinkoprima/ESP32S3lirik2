void autodetect_state_df(){
  ind = myDFPlayer.readState();

  if (ind != last_ind){  

    if(ind != 513) {   // ❗ pakai ind, bukan readState lagi
      // STOP / PAUSE
      tft.fillRect(57, 107,5,18,ST77XX_BLACK);
      tft.fillRect(68, 107,5,18,ST77XX_BLACK);
      tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
    } 
    else {
      // PLAY
      tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
      tft.fillRect(57, 107,5,18,ST77XX_WHITE);
      tft.fillRect(68, 107,5,18,ST77XX_WHITE);
    }
  }

  last_ind = ind;
}

// void autodetect_state_df(){
//   ind = myDFPlayer.readState();
//   if (ind != last_ind){  
//     if(myDFPlayer.readState()!= 513) { 
//     //Serial.println(ind);
//            // 
//             tft.fillRect(57, 107,5,18,ST77XX_BLACK);
//             tft.fillRect(68, 107,5,18,ST77XX_BLACK);
//             tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_RED);
            
//   } 
//     else {//Serial.println(ind); 
//            // 
//             tft.fillTriangle(58, 105, 58, 123, 75, 114, ST77XX_BLACK);
//             tft.fillRect(57, 107,5,18,ST77XX_WHITE);
//             tft.fillRect(68, 107,5,18,ST77XX_WHITE);
//         }
//             }
    
//     last_ind = ind;
// }

////////////////// dfplayer error saat readstate 513 diganti