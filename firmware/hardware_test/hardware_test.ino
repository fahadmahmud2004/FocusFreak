// FocusFreak — Hardware Test
// Checks every component after wiring. Open Serial Monitor at 115200 baud.
// Libraries: U8g2, RTClib, Adafruit HTU21DF, Servo
//
//  Touch Top-L / Top-R / Front -> tones + event in Serial (top touches also wiggle the servo ear)
//  Push button                 -> passive buzzer tone
//  Encoder turn / press        -> counter on OLED / active buzzer beep
//  Type in Serial Monitor      -> sent to phone over Bluetooth (and phone -> Serial)

#include <Wire.h>
#include <SPI.h>
#include <U8g2lib.h>
#include <RTClib.h>
#include <Adafruit_HTU21DF.h>
#include <Servo.h>
#include "pins.h"

U8G2_SSD1309_128X64_NONAME0_F_4W_HW_SPI oled(U8G2_R0, PIN_OLED_CS, PIN_OLED_DC, PIN_OLED_RES);
RTC_DS3231 rtc;
Adafruit_HTU21DF sht;
Servo ear;

bool rtcOk = false;
bool shtOk = false;

volatile long encRaw = 0;
volatile uint8_t encState = 0;
volatile unsigned long sqwTicks = 0;

unsigned long activeOffAt = 0;

// Ear wiggle: non-blocking step sequence, servo detached when idle (no hum, no jitter)
const uint8_t earSteps[] = {SERVO_EAR_MIN, SERVO_EAR_MAX, SERVO_EAR_MIN, SERVO_EAR_MAX, SERVO_EAR_CENTER};
const uint8_t EAR_STEP_COUNT = sizeof(earSteps);
const unsigned long EAR_STEP_MS = 200;
int8_t earStep = -1;          // -1 = idle
unsigned long earNextAt = 0;

void startEarWiggle() {
  if (earStep >= 0) return;   // already wiggling
  ear.attach(PIN_SERVO_EAR);
  earStep = 0;
  earNextAt = millis();
}

void updateEar(unsigned long now) {
  if (earStep < 0 || (long)(now - earNextAt) < 0) return;
  if (earStep < EAR_STEP_COUNT) {
    ear.write(earSteps[earStep]);
    earStep++;
    earNextAt = now + EAR_STEP_MS;
  } else {
    ear.detach();
    earStep = -1;
  }
}

void encoderISR() {
  static const int8_t table[16] = {0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0};
  encState = ((encState << 2) | (digitalRead(PIN_ENC_CLK) << 1) | digitalRead(PIN_ENC_DT)) & 0x0F;
  encRaw += table[encState];
}

void sqwISR() {
  sqwTicks++;
}

void activeBuzzer(bool on) {
  digitalWrite(PIN_BUZZER_ACTIVE, on == BUZZER_ACTIVE_HIGH ? HIGH : LOW);
}

void beepActive(unsigned int ms) {
  activeBuzzer(true);
  activeOffAt = millis() + ms;
}

long readDistanceCm() {
  digitalWrite(PIN_US_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_US_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_US_TRIG, LOW);
  unsigned long us = pulseIn(PIN_US_ECHO, HIGH, 30000UL);
  return us == 0 ? -1 : (long)(us / 58);
}

void scanI2C() {
  Serial.print(F("I2C devices found:"));
  byte count = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print(F(" 0x"));
      Serial.print(addr, HEX);
      count++;
    }
  }
  if (count == 0) Serial.print(F(" NONE (check SDA/SCL)"));
  Serial.println();
  Serial.println(F("  expected: 0x40 (SHT21), 0x68 (RTC), 0x57 (RTC EEPROM)"));
}

// Edge detector for active-high / active-low inputs
struct Edge {
  uint8_t pin;
  bool activeLow;
  bool last;
  const char *name;
  bool pressed() { return digitalRead(pin) == (activeLow ? LOW : HIGH); }
  bool rose() {
    bool now = pressed();
    bool r = now && !last;
    last = now;
    return r;
  }
};

Edge touchL = {PIN_TOUCH_TOP_L, false, false, "Touch Top-Left"};
Edge touchR = {PIN_TOUCH_TOP_R, false, false, "Touch Top-Right"};
Edge touchF = {PIN_TOUCH_FRONT, false, false, "Touch Front"};
Edge button = {PIN_BUTTON, true, false, "Push button"};
Edge encSw  = {PIN_ENC_SW, true, false, "Encoder button"};

void setup() {
  Serial.begin(115200);
  BT_SERIAL.begin(BT_BAUD);

  pinMode(PIN_MEGA_SS, OUTPUT);
  digitalWrite(PIN_MEGA_SS, HIGH);

  pinMode(PIN_US_TRIG, OUTPUT);
  pinMode(PIN_US_ECHO, INPUT);
  pinMode(PIN_BT_STATE, INPUT);
  pinMode(PIN_TOUCH_TOP_L, INPUT);
  pinMode(PIN_TOUCH_TOP_R, INPUT);
  pinMode(PIN_TOUCH_FRONT, INPUT);
  pinMode(PIN_ENC_CLK, INPUT_PULLUP);
  pinMode(PIN_ENC_DT, INPUT_PULLUP);
  pinMode(PIN_ENC_SW, INPUT_PULLUP);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_RTC_SQW, INPUT_PULLUP);
  pinMode(PIN_BUZZER_PASSIVE, OUTPUT);
  pinMode(PIN_BUZZER_ACTIVE, OUTPUT);
  activeBuzzer(false);

  attachInterrupt(digitalPinToInterrupt(PIN_ENC_CLK), encoderISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_DT), encoderISR, CHANGE);

  Serial.println(F("\n===== FocusFreak Hardware Test ====="));

  oled.begin();
  oled.clearBuffer();
  oled.setFont(u8g2_font_6x10_tf);
  oled.drawStr(0, 12, "FocusFreak HW test");
  oled.drawStr(0, 28, "OLED OK");
  oled.sendBuffer();
  Serial.println(F("OLED: sent test screen (if the screen is blank, check OLED wiring)"));

  Wire.begin();
  scanI2C();

  rtcOk = rtc.begin();
  if (rtcOk) {
    if (rtc.lostPower()) {
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
      Serial.println(F("RTC: time was lost, set to compile time"));
    }
    rtc.writeSqwPinMode(DS3231_SquareWave1Hz);
    attachInterrupt(digitalPinToInterrupt(PIN_RTC_SQW), sqwISR, FALLING);
    Serial.println(F("RTC: OK"));
  } else {
    Serial.println(F("RTC: NOT FOUND"));
  }

  shtOk = sht.begin();
  Serial.println(shtOk ? F("SHT21: OK") : F("SHT21: NOT FOUND"));

  Serial.println(F("Buzzers: passive tone now..."));
  tone(PIN_BUZZER_PASSIVE, 880, 200);
  delay(300);
  Serial.println(F("Buzzers: active beep now... (if it beeps constantly instead, set BUZZER_ACTIVE_HIGH false)"));
  beepActive(200);

  Serial.println(F("Servo: moving ear to centre (90 deg), then releasing"));
  ear.attach(PIN_SERVO_EAR);
  ear.write(SERVO_EAR_CENTER);
  delay(600);
  ear.detach();

  Serial.println(F("Ready. Touch / press / turn everything. Type here to send over Bluetooth.\n"));
}

void loop() {
  unsigned long now = millis();

  if (activeOffAt && (long)(now - activeOffAt) >= 0) {
    activeBuzzer(false);
    activeOffAt = 0;
  }

  updateEar(now);

  // ---- Inputs ----
  if (touchL.rose()) { Serial.println(touchL.name); tone(PIN_BUZZER_PASSIVE, 523, 80); startEarWiggle(); }
  if (touchR.rose()) { Serial.println(touchR.name); tone(PIN_BUZZER_PASSIVE, 659, 80); startEarWiggle(); }
  if (touchF.rose()) { Serial.println(touchF.name); tone(PIN_BUZZER_PASSIVE, 784, 80); }
  if (button.rose()) { Serial.println(button.name); tone(PIN_BUZZER_PASSIVE, 1000, 150); }
  if (encSw.rose())  { Serial.println(encSw.name);  beepActive(100); }

  static long lastDetent = 0;
  noInterrupts();
  long detent = encRaw / 4;
  interrupts();
  if (detent != lastDetent) {
    Serial.print(F("Encoder: "));
    Serial.println(detent);
    tone(PIN_BUZZER_PASSIVE, detent > lastDetent ? 2000 : 1500, 8);
    lastDetent = detent;
  }

  // ---- Bluetooth bridge ----
  while (Serial.available()) BT_SERIAL.write(Serial.read());
  while (BT_SERIAL.available()) {
    Serial.print(F("[BT] "));
    Serial.write(BT_SERIAL.read());
    Serial.println();
  }

  // ---- Periodic readings ----
  static unsigned long lastReport = 0;
  if (now - lastReport < 500) return;
  lastReport = now;

  long dist = readDistanceCm();
  int ldr = analogRead(PIN_LDR);
  bool btConn = digitalRead(PIN_BT_STATE);
  float t = shtOk ? sht.readTemperature() : NAN;
  float h = shtOk ? sht.readHumidity() : NAN;
  DateTime dt = rtcOk ? rtc.now() : DateTime((uint32_t)0);
  noInterrupts();
  unsigned long ticks = sqwTicks;
  interrupts();

  char line[24];
  char tbuf[8], hbuf[8];
  dtostrf(t, 4, 1, tbuf);
  dtostrf(h, 4, 1, hbuf);

  oled.clearBuffer();
  if (rtcOk) snprintf(line, sizeof(line), "%02d:%02d:%02d  sqw:%lu", dt.hour(), dt.minute(), dt.second(), ticks);
  else snprintf(line, sizeof(line), "RTC not found");
  oled.drawStr(0, 10, line);
  snprintf(line, sizeof(line), "T:%sC H:%s%%", tbuf, hbuf);
  oled.drawStr(0, 21, line);
  if (dist < 0) snprintf(line, sizeof(line), "Dist: no echo");
  else snprintf(line, sizeof(line), "Dist: %ld cm", dist);
  oled.drawStr(0, 32, line);
  snprintf(line, sizeof(line), "Light: %d", ldr);
  oled.drawStr(0, 43, line);
  snprintf(line, sizeof(line), "Enc:%ld BT:%s", detent, btConn ? "conn" : "--");
  oled.drawStr(0, 54, line);
  snprintf(line, sizeof(line), "L%d R%d F%d B%d S%d",
           touchL.pressed(), touchR.pressed(), touchF.pressed(), button.pressed(), encSw.pressed());
  oled.drawStr(0, 64, line);
  oled.sendBuffer();

  Serial.print(F("dist="));    Serial.print(dist);
  Serial.print(F("cm light=")); Serial.print(ldr);
  Serial.print(F(" T="));      Serial.print(tbuf);
  Serial.print(F(" H="));      Serial.print(hbuf);
  Serial.print(F(" bt="));     Serial.print(btConn ? F("connected") : F("-"));
  Serial.print(F(" sqwTicks=")); Serial.println(ticks);
}
