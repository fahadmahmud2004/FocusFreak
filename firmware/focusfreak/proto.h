// The wire protocol with the app, from `app/docs/PROTOCOL.md` (v1).
//
// Frames: AA 55 CMD LEN PAYLOAD CRC8. The same frames are understood on the
// HC-05 (Serial2, the app) and on USB (Serial, for `tools/sim.py app` and
// testing without a phone). A reply always goes back out of the port the
// request came in on.
#pragma once
#include <Arduino.h>

namespace Proto {

void begin();
void update();

// A phone has talked to us over Bluetooth recently.
bool btActive();

uint8_t crc8(const uint8_t *d, uint16_t n);
uint16_t crc16(const uint8_t *d, uint16_t n);

}  // namespace Proto
