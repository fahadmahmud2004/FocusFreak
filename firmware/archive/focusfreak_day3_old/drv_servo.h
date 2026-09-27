#ifndef DRV_SERVO_H
#define DRV_SERVO_H

#include <Arduino.h>
#include <Servo.h>
#include "config.h"

class ServoDriver {
public:
    ServoDriver(uint8_t pin = PIN_SERVO);

    void init();
    void update();               // Runs in scheduler to handle auto-detach
    void setAngle(uint8_t angle);

    void tiltUp()      { setAngle(SERVO_ANGLE_LOOK_UP); }
    void tiltNeutral() { setAngle(SERVO_ANGLE_NEUTRAL); }
    void tiltDown()    { setAngle(SERVO_ANGLE_LOOK_DOWN); }

    void selfTestSweep();        // Boot calibration sweep

    uint8_t getCurrentAngle() const { return _currentAngle; }
    bool isAttached() const { return _isAttached; }

private:
    uint8_t _pin;
    Servo _servo;
    uint8_t _currentAngle;
    uint8_t _targetAngle;
    bool _isAttached;
    uint32_t _moveStartTime;

    void attach();
    void detach();
};

#endif // DRV_SERVO_H
