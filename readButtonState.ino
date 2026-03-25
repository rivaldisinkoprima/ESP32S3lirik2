int buttonStatePrevious = HIGH;                      // previousstate of the switch
unsigned long minButtonLongPressDuration = 2000;    // Time we wait before we see the press as a long press
unsigned long buttonLongPressMillis;                // Time in ms when we the button was pressed
bool buttonStateLongPress = false;                  // True if it is a long press
const int intervalButton = 50;                      // Time between two readings of the button state
unsigned long previousButtonMillis;                 // Timestamp of the latest reading
unsigned long buttonPressDuration;                  // Time the button is pressed in ms
void readButtonState() {
  if(currentMillis - previousButtonMillis > intervalButton) {
    int buttonState = digitalRead(buttonPower);    
    if (buttonState == LOW && buttonStatePrevious == HIGH && !buttonStateLongPress) {
      buttonLongPressMillis = currentMillis;
      buttonStatePrevious = LOW;
      Serial.println("Button pressed");
    }
    buttonPressDuration = currentMillis - buttonLongPressMillis;
    if (buttonState == LOW && !buttonStateLongPress && buttonPressDuration > minButtonLongPressDuration) {
      buttonStateLongPress = true;
      Serial.println("Button long pressed");
      tft.fillScreen(ST77XX_BLACK);
      tft.setCursor(37, 68);          // x=15, y=50
      tft.print("OFF");
      digitalWrite(TrigMic,LOW);
      digitalWrite(TrigRlyDF,LOW);
      delay(200);
      digitalWrite(TrigMic,LOW);
      digitalWrite(TrigRlyDF,LOW);
      digitalWrite(17,LOW);
      digitalWrite(TrigPower,HIGH);
      //digitalWrite(pinLED, LOW);

    }
    if (buttonState == HIGH && buttonStatePrevious == LOW) {
      buttonStatePrevious = HIGH;
      buttonStateLongPress = false;
      Serial.println("Button released");
      if (buttonPressDuration < minButtonLongPressDuration) {
        Serial.println("Button pressed shortly");
      }
        if (buttonPressDuration >= minButtonLongPressDuration) {
        Serial.println("Button pressed longly");

      }
      //digitalWrite(TrigPower,LOW);
    }
    previousButtonMillis = currentMillis;
  }
}