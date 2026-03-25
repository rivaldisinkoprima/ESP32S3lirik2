void tampiljam(){
  tft.setFont(NULL);
  tft.setCursor(5,2);
  if (l_hour < 10) tft.print("0");
  tft.print(l_hour);
  tft.print(":");
  if (l_minute < 10) tft.print("0");
  tft.print(l_minute);
  tft.setFont(&FreeSans9pt7b); // Atur font
}