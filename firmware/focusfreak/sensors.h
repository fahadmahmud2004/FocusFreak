// Every input: the clock, the room sensors, and the controls.
//
// Nothing here blocks for long. The SHT21 is read with its no-hold commands
// and polled later, the ultrasonic ping is capped at 15 ms, and the controls
// are debounced by time, so the face keeps its 25 fps.
#pragma once
#include <Arduino.h>

#include "world.h"

namespace Sensors_ {

void begin();
void update();

// What the sensors read now. presenceMin/Max are filled by the caller.
void read(Sensors &out);
const Clock &now();
bool rtcOk();
bool shtOk();
bool sonarOk();  // has echoed at least once since boot
bool btLinked();

// Sets the RTC (from the app's SET_TIME).
void setTime(uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, uint8_t second);

// The next control event, if any.
bool nextKey(BotKey &k, uint32_t &atMs);

}  // namespace Sensors_
