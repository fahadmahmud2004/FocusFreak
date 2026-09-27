/* ==========================================================================
 *  PROJECT FOCUSFREAK — FIRMWARE (DAY 3: SERVO HEAD-TILT INTEGRATION)
 *  Hardware: Arduino Mega 2560 + 2.4" OLED + HC-SR04 + SG90 Servo (Pin 45)
 * ========================================================================== */

#include <Arduino.h>
#include <SPI.h>
#include <U8g2lib.h>

#include "config.h"
#include "drv_sensors.h"
#include "drv_servo.h"
#include "face.h"
#include "ui.h"

/* ========================================================================== */
/*                      DISPLAY CONSTRUCTOR SELECTION                         */
/* ========================================================================== */
// 1. For SSD1309 / SSD1306 2.4" OLED (Hardware SPI on Mega: SCK=52, MOSI=51)
U8G2_SSD1309_128X64_NONAME0_F_4W_HW_SPI u8g2(
    U8G2_R0, 
    /* cs= */ OLED_PIN_CS, 
    /* dc= */ OLED_PIN_DC, 
    /* reset= */ OLED_PIN_RES
);

/* ========================================================================== */
/*                           MODULE INSTANCES                                 */
/* ========================================================================== */
FaceRenderer face(u8g2);
UIManager ui(u8g2, face);
SensorDriver sensors(PIN_TRIG, PIN_ECHO);
ServoDriver headServo(PIN_SERVO);

/* ========================================================================== */
/*                          COOPERATIVE SCHEDULER                             */
/* ========================================================================== */
static uint32_t lastFaceTick = 0;
static uint32_t lastSensorTick = 0;
static uint32_t lastServoTick = 0;
static uint32_t lastLogTick = 0;
static uint32_t lastIdleGazeTick = 0;
static uint8_t idleGazeState = 0;

void setup() {
    // 1. Initialize Serial monitor
    Serial.begin(DEBUG_BAUD_RATE);
    while (!Serial && millis() < 2000);

    Serial.println(F("\n=============================================="));
    Serial.println(F("   FOCUSFREAK v2 — FIRMWARE DAY 3 BOOT       "));
    Serial.println(F("   OLED + Distance + SG90 Servo Head-Tilt    "));
    Serial.println(F("=============================================="));

    // 2. Arduino Mega hardware SPI requirement: Pin 53 (SS) must be OUTPUT
    pinMode(MEGA_SPI_SS_PIN, OUTPUT);
    digitalWrite(MEGA_SPI_SS_PIN, HIGH);

    // 3. Initialize OLED display
    Serial.print(F("Initializing OLED Display... "));
    u8g2.begin();
    ui.init();
    ui.setMode(SCREEN_FACE_DEMO);
    Serial.println(F("[OK]"));

    // 4. Initialize Ultrasonic Sensor
    Serial.print(F("Initializing HC-SR04 Sensor (Trig: 22, Echo: 24)... "));
    sensors.init();
    Serial.println(F("[OK]"));

    // 5. Initialize & Test Servo Driver
    Serial.print(F("Initializing SG90 Servo (Pin: 45)... "));
    headServo.init();
    Serial.println(F("[OK]"));

    // Run startup sweep self-test
    headServo.selfTestSweep();

    Serial.println(F("System Ready! Move your hand in front of the sensor to see head-tilt."));
}

void loop() {
    uint32_t now = millis();

    // -------------------------------------------------------------------------
    // Task 1: Face Animation & UI Rendering (25 FPS / 40 ms)
    // -------------------------------------------------------------------------
    if (now - lastFaceTick >= FACE_TICK_MS) {
        lastFaceTick = now;
        face.update();
        ui.render();
    }

    // -------------------------------------------------------------------------
    // Task 2: Sensor Driver & Approach Reactions (10 Hz / 100 ms)
    // -------------------------------------------------------------------------
    if (now - lastSensorTick >= SENSOR_TICK_MS) {
        lastSensorTick = now;
        sensors.update();

        // Check if user just approached or left
        if (sensors.hasPresenceChanged()) {
            if (sensors.isPersonPresent()) {
                Serial.println(F("\n>>> [EVENT] User Approach Detected! (< 60 cm)"));
                Serial.print(F(">>> Distance: "));
                Serial.print(sensors.getFilteredDistanceCm());
                Serial.println(F(" cm -> Head Tilting UP + Face Alert"));

                // Face Reaction
                face.setMood(MOOD_CALM);
                face.setGaze(GAZE_CENTER);
                face.triggerBlink();

                // Physical Servo Reaction: Tilt head UP towards user
                headServo.tiltUp();
            } else {
                Serial.println(F("\n>>> [EVENT] User Left Desk (> 80 cm)"));
                Serial.println(F(">>> Head Tilting NEUTRAL + Bot Idle"));

                // Face Reaction
                face.setMood(MOOD_SLEEPY);

                // Physical Servo Reaction: Return head to neutral resting angle
                headServo.tiltNeutral();
            }
        }

        // Continuous presence behavior
        if (sensors.isPersonPresent()) {
            face.setGaze(GAZE_CENTER);
        } else {
            // Idle behavior: Wander eyes left/right every 2.5 seconds when desk is empty
            if (now - lastIdleGazeTick >= 2500) {
                lastIdleGazeTick = now;
                idleGazeState = (idleGazeState + 1) % 3;
                if (idleGazeState == 0) face.setGaze(GAZE_CENTER);
                else if (idleGazeState == 1) face.setGaze(GAZE_LEFT);
                else face.setGaze(GAZE_RIGHT);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Task 3: Servo Auto-Detach Manager (20 Hz / 50 ms)
    // -------------------------------------------------------------------------
    if (now - lastServoTick >= SERVO_TICK_MS) {
        lastServoTick = now;
        headServo.update();
    }

    // -------------------------------------------------------------------------
    // Task 4: Periodic Telemetry Logging (Every 1000 ms)
    // -------------------------------------------------------------------------
    if (now - lastLogTick >= 1000) {
        lastLogTick = now;
        Serial.print(F("[TELEMETRY] Dist: "));
        if (sensors.getFilteredDistanceCm() == 999) Serial.print(F("Out of range"));
        else {
            Serial.print(sensors.getFilteredDistanceCm());
            Serial.print(F(" cm"));
        }

        Serial.print(F(" | Presence: "));
        Serial.print(sensors.isPersonPresent() ? F("PRESENT") : F("EMPTY"));

        Serial.print(F(" | Head Angle: "));
        Serial.print(headServo.getCurrentAngle());
        Serial.print(F("° ("));
        Serial.print(headServo.isAttached() ? F("MOVING") : F("SILENT"));
        Serial.println(F(")"));
    }
}
