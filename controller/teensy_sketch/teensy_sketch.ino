const int buttonPin = 8;
bool lastButtonState = HIGH;
bool currentButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

String serialBuffer = "";

void clearLCD() {
  Serial1.write(0xFE);
  Serial1.write(0x01);
  delay(50);
}

void lcdPrintLine(uint8_t row, const String &text) {
  int row_offsets[] = { 0x00, 0x40 };
  String padded = text;
  while (padded.length() < 16) {
    padded += " ";
  }
  Serial1.write(0xFE);
  Serial1.write(0x80 + row_offsets[row]);
  Serial1.print(padded.substring(0, 16));
}

String formatAltitude(String raw) {
  float alt = raw.toFloat();
  String formatted;

  if (alt >= 10000) {
    formatted = String(alt / 1000.0, 2) + " km";
  } else {
    formatted = String((int)alt) + " m";
  }

  return "ALT: " + formatted;
}

void setup() {
  pinMode(buttonPin, INPUT_PULLUP);
  Serial.begin(9600);   // USB serial for receiving altitude
  Serial1.begin(9600);  // UART for LCD
  delay(500);

  clearLCD();
  lcdPrintLine(0, "Teensy Ready");
  lcdPrintLine(1, "Waiting...");
}

void loop() {
  // --- Button handling ---
  int reading = digitalRead(buttonPin);

  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != currentButtonState) {
      currentButtonState = reading;

      if (currentButtonState == LOW) {
        // Button just pressed
        Serial.write('T');
        lcdPrintLine(0, "Mode Switch");
        lcdPrintLine(1, "Sent 'T'");
      }
    }
  }

  lastButtonState = reading;

  // --- Serial handling for altitude updates ---
  while (Serial.available()) {
    char incomingChar = Serial.read();

    if (incomingChar == '\n') {
      String formatted = formatAltitude(serialBuffer);
      lcdPrintLine(1, formatted);
      // Complete message received — update LCD line 1
      lcdPrintLine(1, serialBuffer);
      serialBuffer = "";
    } else {
      serialBuffer += incomingChar;
      if (serialBuffer.length() > 16) {
        serialBuffer = serialBuffer.substring(0, 16); // truncate if too long
      }
    }
  }
}
