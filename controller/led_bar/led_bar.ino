#include <SPI.h>

// === Pins ===
const int buttonPin = 8;
const int shiftDataPin = 2;   // SER
const int shiftClockPin = 3;  // SRCLK
const int shiftLatchPin = 4;  // RCLK

bool lastButtonState = HIGH;
bool currentButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

String serialBuffer = "";

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
  int segments = map(chargePercent, 0, 100, 0, 10);
  uint16_t output = 0;
  for (int i = 0; i < segments; i++) {
    output |= (1 << i);
  }

  digitalWrite(shiftLatchPin, LOW);

  // REVERSED ORDER: send low byte first
  shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, output & 0xFF);
  shiftOut(shiftDataPin, shiftClockPin, MSBFIRST, (output >> 8) & 0xFF);

  digitalWrite(shiftLatchPin, HIGH);

  Serial.print("Charge segments: ");
  Serial.print(segments);
  Serial.print(", Output bits: ");
  Serial.println(output, BIN);
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
