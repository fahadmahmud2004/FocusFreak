#include "drv_servo.h"

ServoDriver::ServoDriver(uint8_t pin)
    : _pin(pin),
      _currentAngle(SERVO_ANGLE_NEUTRAL),
      _targetAngle(SERVO_ANGLE_NEUTRAL),
      _isAttached(false),
      _moveStartTime(0) {}

void ServoDriver::init() {
    attach();
    _servo.write(SERVO_ANGLE_NEUTRAL);
    _currentAngle = SERVO_ANGLE_NEUTRAL;
    _targetAngle = SERVO_ANGLE_NEUTRAL;
    _moveStartTime = millis();
}

void ServoDriver::attach() {
    if (!_isAttached) {
        uint8_t ch = _servo.attach(_pin, 544, 2400); // Standard 544us - 2400us SG90 pulse range
        _isAttached = true;
        Serial.print(F("[SERVO] Attached to Pin "));
        Serial.print(_pin);
        Serial.print(F(" (Channel ID: "));
        Serial.print(ch);
        Serial.println(F(")"));
    }
}

void ServoDriver::detach() {
    if (_isAttached) {
        _servo.detach();
        _isAttached = false;
    }
}

void ServoDriver::setAngle(uint8_t angle) {
    // Clamp angle to safe operational range (20° to 160°)
    if (angle < 20) angle = 20;
    if (angle > 160) angle = 160;

    attach();
    _servo.write(angle);
    _targetAngle = angle;
    _currentAngle = angle;
    _moveStartTime = millis();
}

void ServoDriver::update() {
    // Keep attached during test phase so motor holds position
}

void ServoDriver::selfTestSweep() {
    Serial.println(F("\n========================================"));
    Serial.println(F("[SERVO TEST] Testing Servo Movement..."));
    Serial.println(F("1. Moving to 30° (Left)"));
    setAngle(30);
    delay(1000);

    Serial.println(F("2. Moving to 150° (Right)"));
    setAngle(150);
    delay(1000);

    Serial.println(F("3. Moving to 90° (Center)"));
    setAngle(SERVO_ANGLE_NEUTRAL);
    delay(1000);

    Serial.println(F("[SERVO TEST] Sweep Complete!"));
    Serial.println(F("========================================\n"));
}
