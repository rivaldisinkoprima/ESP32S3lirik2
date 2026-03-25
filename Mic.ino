void mic(){
if (digitalRead(buttonMDokter) == HIGH) {
digitalWrite(TrigMic,HIGH);
digitalWrite(TrigRlyDF,LOW);
myDFPlayer.stop();
tft.fillRect(66,140,100,25,ST77XX_BLACK);
tft.setCursor(63,155);
tft.print("mic doc");
Serial.println("dokter bicara");
dokter_bicara = true;
}}
