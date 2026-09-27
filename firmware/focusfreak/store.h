// EEPROM: settings, the pushed routine, and 30 days of logs.
//
// An EEPROM byte takes 3.4 ms to write, and a routine is 768 bytes: written
// in one go that is 2.6 s with the loop frozen and the Bluetooth buffer
// overflowing. So every write goes through a background writer that puts
// down one byte whenever the EEPROM is ready, and skips bytes that already
// hold the right value.
//
// Map (4096 bytes):
//   0x000  magic "FF" + layout version
//   0x004  BotSettings
//   0x080  routine header: active bank, block count per bank
//   0x090  routine bank 0, 16 x 48
//   0x390  routine bank 1, 16 x 48
//   0x690  day logs, 30 x 12
#pragma once
#include <Arduino.h>

#include "world.h"

#define MAX_BLOCKS 16
#define BLOCK_SIZE 48
#define LOG_DAYS 30

struct DayLog {
  uint16_t date;  // days since 2026-01-01, 0xFFFF = empty
  uint16_t verifiedMin;
  uint16_t claimedMin;
  uint8_t blocksDone;
  uint8_t blocksTotal;
  uint8_t violations;
  uint8_t reserved[3];
};

namespace Store {

void begin(BotSettings &settings);
void update();
bool busy();

void saveSettings(const BotSettings &settings);

// The routine pushed by the app. Reads come from RAM while a commit is
// still being written to EEPROM.
uint8_t routineCount();
void readBlock(uint8_t index, uint8_t *out48);
// Commits [count] blocks held in [staging] (RAM, count * 48 bytes). The
// caller keeps [staging] untouched until routineWriting() is false.
void commitRoutine(const uint8_t *staging, uint8_t count);
bool routineWriting();

// Day logs, a ring indexed by date % 30.
bool readLog(uint16_t date, DayLog &out);
// [log] must stay valid (a static) until the write finishes.
void writeLog(const DayLog *log);

}  // namespace Store
