// The focus session: the device's own state machine, routines, verification,
// mood and day log.
//
// Mirrors `lib/domain/engine/session_engine.dart` and `mood_engine.dart` in
// the app. The bot runs it on its own; with a phone connected the app pushes
// routines and pause/resume/skip/stop over `0x70 CONTROL`, and reads the result
// in `0xB0 STATUS`.
#pragma once
#include <Arduino.h>

#include "store.h"
#include "world.h"

// Wire values of STATUS.state (docs/PROTOCOL.md section 6).
enum RunState : uint8_t { RS_IDLE, RS_ARMED, RS_RUNNING, RS_PAUSED, RS_COMPLETE, RS_BROKEN };

struct Block {
  char name[17];
  char desc[25];
  uint16_t durationMin;
  uint8_t category;
  bool tracked;
};

namespace Session_ {

void begin();
// Call every loop with what the sensors read.
void update(const Sensors &s);

// Starting things.
void startQuick(uint16_t minutes);
void startTemplate(uint8_t index);
void startBlock(uint8_t index);  // in the active routine
void pause();
void resume();
void skip();
void stop();

// The app pushed a routine: it is now the active one, and the session idles
// until the app says which block to start.
void routinePushed();

// The phone's heartbeat.
void heartbeat(bool screenLocked);

// What the rest of the firmware reads.
void fill(Session &out);
BotMood mood();
void pet();
uint16_t verifiedMinutesToday();
uint8_t streak();
bool presentStable();

// Wire frames.
void statusPayload(uint8_t out[12]);
uint8_t activeCount();
void activeBlockBytes(uint8_t index, uint8_t out[48]);
uint16_t today();
bool logFor(uint16_t date, DayLog &out);

// 0 CALM 1 SEARCHING 2 SAD 3 HAPPY 4 SLEEPY on the wire.
uint8_t moodToWire(BotMood m);

}  // namespace Session_
