void aturjam(){ 
  myDFPlayer.stop();
  isPlaying = false; 
  posisi = 3;
  tft.setCursor(15,88);
  tft.setTextSize(2);
  tft.print("00:00");
  tft.setTextSize(1);
}
//init
