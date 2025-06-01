// Teensy + kRPC Altitude Delta Graph (Matrix) + Altitude on LCD
#include <MD_MAX72xx.h>
#include <SPI.h>
#include <math.h>

// === Matrix Setup ===
#define HARDWARE_TYPE MD_MAX72XX::FC16_HW
#define MAX_DEVICES 4
#define DATA_PIN 11  // MOSI
#define CS_PIN 10    // Chip select
#define CLK_PIN 13   // SCK
#define MATRIX_HEIGHT 8
MD_MAX72XX mx(HARDWARE_TYPE, CS_PIN, MAX_DEVICES);

// === LCD Setup ===
#define NUM_COLS (MAX_DEVICES * 8)
#define LCD_BAUD 9600
const int buttonPin = 8;
bool lastButtonState = HIGH;
bool currentButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;
long lastDisplayedAlt = -1;


// Altitude history buffer
uint8_t altitudeHistory[NUM_COLS];
uint8_t columnIndex = 0;

const long ALTITUDE_MAX = 80000; // 80 km

void clearLCD() {
  Serial1.write(0xFE);
  Serial1.write(0x01);
  delay(50);
}

void lcdPrintLine(uint8_t row, const String &text) {
  int row_offsets[] = { 0x00, 0x40 };
  Serial1.write(0xFE);
  Serial1.write(0x80 + row_offsets[row]);
  Serial1.print(text.substring(0, 16));
}

void setup() {
  pinMode(buttonPin, INPUT_PULLUP);
  Serial.begin(9600);
  Serial1.begin(9600);
  mx.begin();
  mx.control(MD_MAX72XX::INTENSITY, 3);  // Dim matrix
  mx.clear();
  clearLCD();
  lcdPrintLine(0, "Teensy Ready 2.1");
  lcdPrintLine(1, "Waiting...");

  for (int i = 0; i < NUM_COLS; i++) altitudeHistory[i] = 0;
}

// === Altitude Graph State ===
bool useSurfaceAlt = true;

void drawAltitudeGraph() {
  mx.clear();
  for (int x = 0; x < NUM_COLS; x++) {
    uint8_t height = altitudeHistory[x];
    mx.setPoint(MATRIX_HEIGHT - 1 - height, x, true);  // one pixel at scaled height
  }
}

void updateAltitudeGraph(int alt) {
  long alt_clamped = max(alt, 1);  // avoid log(0)
  float log_min = log(1);
  float log_max = log(ALTITUDE_MAX);
  float log_val = log(alt_clamped);
  uint8_t scaled = (uint8_t)((log_val - log_min) / (log_max - log_min) * (MATRIX_HEIGHT - 1));
  scaled = min(scaled, MATRIX_HEIGHT - 1);

  if (columnIndex < NUM_COLS) {
    altitudeHistory[columnIndex++] = scaled;
  } else {
    for (int i = 0; i < NUM_COLS - 1; i++) {
      altitudeHistory[i] = altitudeHistory[i + 1];
    }
    altitudeHistory[NUM_COLS - 1] = scaled;
  }

  drawAltitudeGraph();
}


String inputLine = "";

void loop() {
  int reading = digitalRead(buttonPin);
  if (reading != lastButtonState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != currentButtonState) {
      currentButtonState = reading;
      if (currentButtonState == LOW) {
        Serial.write('T');
        useSurfaceAlt = !useSurfaceAlt;
        clearLCD();
        lcdPrintLine(0, "Mode Switched");
        lcdPrintLine(1, useSurfaceAlt ? "Surface Alt" : "Mean Alt");
      }
    }
  }
  lastButtonState = reading;

  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') {
      if (inputLine.startsWith("A:")) {
        int sep = inputLine.indexOf(':', 2);
        if (sep != -1) {
          int alt = inputLine.substring(2, sep).toInt();
          updateAltitudeGraph(alt);
          if (lastDisplayedAlt == -1) {
            clearLCD();
            lcdPrintLine(0, useSurfaceAlt ? "Surf Alt (m)" : "Mean Alt (m)");
            lcdPrintLine(1, String(alt));
            lastDisplayedAlt = alt;
          } else if (alt != lastDisplayedAlt) {
            lcdPrintLine(1, String(alt));
            lastDisplayedAlt = alt;
          }
        }
      }
      inputLine = "";
    } else {
      inputLine += c;
    }
  }
}
