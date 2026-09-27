// FocusFreak — FINAL pin map (matches docs/WIRING.md).
// Copy this file into every sketch. Change pins ONLY here.
#pragma once

// ---------- OLED 2.42" SSD1309 (hardware SPI: MOSI=D51, SCK=D52 are fixed) ----------
#define PIN_OLED_CS         48
#define PIN_OLED_DC         47
#define PIN_OLED_RES        49
#define PIN_MEGA_SS         53   // nothing wired, but must stay OUTPUT for SPI master mode

// ---------- I2C bus (SDA=D20, SCL=D21 are fixed, used via Wire) ----------
#define I2C_ADDR_SHT21      0x40
#define I2C_ADDR_RTC        0x68
#define PIN_RTC_SQW         2    // interrupt-capable, 1 Hz tick / alarm

// ---------- HC-SR04 ultrasonic ----------
#define PIN_US_TRIG         22
#define PIN_US_ECHO         24

// ---------- HC-05 Bluetooth on Serial2 (TX2=D16 -> divider -> RXD, RX2=D17 <- TXD) ----------
#define BT_SERIAL           Serial2
#define BT_BAUD             9600
#define PIN_BT_STATE        26   // HIGH while a phone is connected

// ---------- LDR light sensor (bare LDR + resistor divider, middle joint) ----------
#define PIN_LDR             A8   // analogRead 0-1023, HIGHER = brighter

// ---------- Touch sensors (TTP223, HIGH = touched) ----------
#define PIN_TOUCH_TOP_L     28
#define PIN_TOUCH_TOP_R     30
#define PIN_TOUCH_FRONT     42

// ---------- Rotary encoder (swap CLK/DT here if direction is reversed) ----------
#define PIN_ENC_CLK         18   // interrupt-capable
#define PIN_ENC_DT          19   // interrupt-capable
#define PIN_ENC_SW          32   // INPUT_PULLUP, LOW = pressed

// ---------- Push button ----------
#define PIN_BUTTON          34   // INPUT_PULLUP, LOW = pressed

// ---------- Buzzers ----------
#define PIN_BUZZER_PASSIVE  38   // use tone()
#define PIN_BUZZER_ACTIVE   40   // HIGH = beep (set false below if your module is low-level trigger)
#define BUZZER_ACTIVE_HIGH  true

// ---------- SG90 servo "ear" (power from breadboard rail, NOT a Mega pin) ----------
// Servo library uses Timer5 on the Mega: D44/D45/D46 lose analogWrite() PWM.
#define PIN_SERVO_EAR       45
#define SERVO_EAR_CENTER    90   // neutral ear position (attach the horn at this angle)
#define SERVO_EAR_MIN       60   // wiggle limits: shrink these if the ear hits the box
#define SERVO_EAR_MAX       120
