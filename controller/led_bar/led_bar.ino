#include <SPI.h>

// === Pins ===
const int buttonPin = 8;
const int shiftDataPin = 3;   // SER
const int shiftClockPin = 4;  // SRCLK
const int shiftLatchPin = 5;  // RCLK

bool lastButtonState = HIGH;
bool currentButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

String serialBuffer = "";

uint8_t pwmStep = 0;          // Flicker PWM emulation step

// === LCD ===
void clearLCD() {
  Serial1.write(0xFE);
  Serial1.write(0x01);
  delay(50);
}

void lcdPrintLine(uint8_t row, const String &text) {
  int row_offsets[] = { 0x00, 0x40 };
  String padded = text;
  while (padded.length() < 16) padded += " ";
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

// === LED BAR ===
void updateLEDBarShiftRegister(int chargePercent) {
  int totalSegments = map(chargePercent, 0, 100, 0, 1000); // 0 to 1000
  int fullSegments = totalSegments / 100;
  int partialBrightness = totalSegments % 100;
  uint16_t output = 0;

  for (int i = 0; i < fullSegments; i++) {
    output |= (1 << (9 - i));  // Flip orientation
  }

  if (fullSegments < 10) {
    int flickerThreshold = map(partialBrightness, 0, 100, 0, 4);
    if (pwmStep < flickerThreshold) {
      output |= (1 << (9 - fullSegments));
    }
  }

  digitalWrite(shiftLatchPin, LOW);
  shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, (output >> 8) & 0xFF);
  shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, output & 0xFF);
  digitalWrite(shiftLatchPin, HIGH);

  pwmStep = (pwmStep + 1) % 4;
}

String inputLine = "";


void testEachBitIndividually() {
  for (int i = 0; i < 16; i++) {
    uint16_t testPattern = (1 << i);

    digitalWrite(shiftLatchPin, LOW);
    shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, (testPattern >> 8) & 0xFF);
    shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, testPattern & 0xFF);
    digitalWrite(shiftLatchPin, HIGH);

    Serial.print("Testing bit ");
    Serial.println(i);

    delay(1000);  // wait and observe
  }
}


void setup() {
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(shiftDataPin, OUTPUT);
  pinMode(shiftClockPin, OUTPUT);
  pinMode(shiftLatchPin, OUTPUT);

  Serial.begin(9600);   // USB serial
  Serial1.begin(9600);  // UART for LCD
  delay(500);

  clearLCD();
  lcdPrintLine(0, "Teensy Ready");
  lcdPrintLine(1, "Waiting...");

  updateLEDBarShiftRegister(0); // Clear bar initially
  testEachBitIndividually();
}

void loop() {
  // --- Button handling ---
  int reading = digitalRead(buttonPin);
  if (reading != lastButtonState) lastDebounceTime = millis();

  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != currentButtonState) {
      currentButtonState = reading;
      if (currentButtonState == LOW) {
        Serial.write('T');
        lcdPrintLine(0, "Mode Switch");
        lcdPrintLine(1, "Sent 'T'");
      }
    }
  }
  lastButtonState = reading;

  static unsigned long lastPwmUpdate = 0;
  if (millis() - lastPwmUpdate >= 100) {
    pwmStep = (pwmStep + 1) % 4;  // Adjust 4 to control flicker frequency
    lastPwmUpdate = millis();
  }


  // --- Serial handling ---
  while (Serial.available()) {
    char incomingChar = Serial.read();

    if (incomingChar == '\n') {
      int sep = serialBuffer.indexOf(':');
      if (sep != -1) {
        String altStr = serialBuffer.substring(0, sep);
        String chargeStr = serialBuffer.substring(sep + 1);
        lcdPrintLine(1, formatAltitude(altStr));
        updateLEDBarShiftRegister(chargeStr.toInt());
      }
      serialBuffer = "";
    } else {
      serialBuffer += incomingChar;
      if (serialBuffer.length() > 32) serialBuffer = ""; // avoid buffer overflow
    }
  }
}
