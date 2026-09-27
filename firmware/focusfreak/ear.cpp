#include "ear.h"

#include <Servo.h>

#include "pins.h"

namespace Ear {

static Servo s_servo;
static const uint8_t STEPS[] = {SERVO_EAR_MIN, SERVO_EAR_MAX, SERVO_EAR_MIN, SERVO_EAR_MAX, SERVO_EAR_CENTER};
static const uint16_t STEP_MS = 200;
static int8_t s_step = -1;  // -1 = still
static uint32_t s_nextAt = 0;
static uint32_t s_detachAt = 0;

void begin() {
  // Centre once at power-up, then let go. This is the position to fit the
  // horn at (docs/WIRING.md, section 3.11).
  s_servo.attach(PIN_SERVO_EAR);
  s_servo.write(SERVO_EAR_CENTER);
  s_detachAt = millis() + 600;
}

void wiggle() {
  if (s_step >= 0) return;  // already wiggling
  if (!s_servo.attached()) s_servo.attach(PIN_SERVO_EAR);
  s_detachAt = 0;
  s_step = 0;
  s_nextAt = millis();
}

void update() {
  uint32_t now = millis();
  if (s_detachAt && (int32_t)(now - s_detachAt) >= 0) {
    s_detachAt = 0;
    s_servo.detach();
  }
  if (s_step < 0 || (int32_t)(now - s_nextAt) < 0) return;
  if (s_step < (int8_t)sizeof(STEPS)) {
    s_servo.write(STEPS[s_step++]);
    s_nextAt = now + STEP_MS;
  } else {
    s_step = -1;
    s_servo.detach();
  }
}

}  // namespace Ear
