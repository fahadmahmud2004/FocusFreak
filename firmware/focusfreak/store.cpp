#include "store.h"

#include <avr/eeprom.h>

namespace Store {

static const uint16_t ADDR_MAGIC = 0x000;
static const uint16_t ADDR_SETTINGS = 0x004;
static const uint16_t ADDR_HEADER = 0x080;
static const uint16_t ADDR_BANK0 = 0x090;
static const uint16_t ADDR_BANK1 = 0x390;
static const uint16_t ADDR_LOGS = 0x690;

static const uint8_t LAYOUT_VERSION = 1;
static const uint8_t SETTINGS_VERSION = 3;

static_assert(sizeof(BotSettings) <= ADDR_HEADER - ADDR_SETTINGS, "settings too big for their EEPROM slot");
static_assert(sizeof(DayLog) == 12, "DayLog must be 12 bytes, as LOG_ENTRY on the wire");
static_assert(ADDR_LOGS + LOG_DAYS * sizeof(DayLog) <= 4096, "EEPROM map overflows");

struct Header {
  uint8_t activeBank;
  uint8_t count[2];
  uint8_t reserved;
};
static Header s_hdr;
static const uint8_t *s_staging = nullptr;
static uint8_t s_stagingCount = 0;
static bool s_writing = false;
static uint8_t s_newBank = 0;
static const uint8_t s_magic[4] = {'F', 'F', LAYOUT_VERSION, 0};

// --- background writer --------------------------------------------------------

enum Tag : uint8_t { T_PLAIN, T_BANK, T_HEADER };

struct Job {
  const uint8_t *src;  // RAM; null = fill with [fill]
  uint16_t addr;
  uint16_t len;
  uint16_t pos;
  uint16_t seq;
  uint8_t fill;
  uint8_t tag;
  bool active;
};
static Job s_jobs[6];
static uint16_t s_seq = 0;

static void finished(const Job &j);

static void enqueue(const uint8_t *src, uint16_t addr, uint16_t len, uint8_t tag, uint8_t fill = 0xFF) {
  // The same region queued again: start it over with the newest data.
  for (Job &j : s_jobs) {
    if (j.active && j.addr == addr && j.len == len && j.src == src) {
      j.pos = 0;
      return;
    }
  }
  for (Job &j : s_jobs) {
    if (!j.active) {
      j = {src, addr, len, 0, s_seq++, fill, tag, true};
      return;
    }
  }
  // No free slot (should not happen): write it now, slowly but surely.
  for (uint16_t i = 0; i < len; i++) eeprom_update_byte((uint8_t *)(addr + i), src ? src[i] : fill);
  Job j = {src, addr, len, len, 0, fill, tag, false};
  finished(j);
}

static void finished(const Job &j) {
  if (j.tag == T_BANK) {
    s_hdr.count[s_newBank] = s_stagingCount;
    s_hdr.activeBank = s_newBank;
    // The header last: power lost before this point leaves the old routine.
    enqueue((const uint8_t *)&s_hdr, ADDR_HEADER, sizeof(s_hdr), T_HEADER);
  } else if (j.tag == T_HEADER) {
    s_writing = false;
  }
}

void update() {
  // One byte per call at most, and only when the EEPROM is free: the loop
  // never waits on it.
  for (uint8_t guard = 0; guard < 64; guard++) {
    if (!eeprom_is_ready()) return;
    Job *job = nullptr;
    for (Job &j : s_jobs) {
      if (j.active && (!job || j.seq < job->seq)) job = &j;
    }
    if (!job) return;
    while (job->pos < job->len) {
      uint16_t i = job->pos++;
      uint8_t want = job->src ? job->src[i] : job->fill;
      uint8_t *a = (uint8_t *)(job->addr + i);
      if (eeprom_read_byte(a) != want) {
        eeprom_write_byte(a, want);
        return;
      }
    }
    job->active = false;
    finished(*job);
  }
}

bool busy() {
  for (const Job &j : s_jobs) {
    if (j.active) return true;
  }
  return false;
}

// --- settings -----------------------------------------------------------------

static void defaults(BotSettings &s) {
  memset(&s, 0, sizeof(s));
  s.version = SETTINGS_VERSION;
  s.sound = true;
  s.brightness = 2;
  s.faceHome = true;
  s.playMode = PM_ONCE;
  s.alarms[0] = {false, 6, 30, 0, 0x7F};
  s.alarms[1] = {false, 7, 30, 0, 0x4F};
  s.alarms[2] = {false, 14, 0, 0, 0};
  s.alarms[3] = {false, 22, 0, 0, 0};
  s.presenceMin = 20;
  s.presenceMax = 90;
  s.autoPause = false;
  s.graceRunningS = 30;
  s.gracePausedS = 300;
}

void saveSettings(const BotSettings &s) {
  enqueue((const uint8_t *)&s, ADDR_SETTINGS, sizeof(BotSettings), T_PLAIN);
}

void begin(BotSettings &settings) {
  uint8_t magic[4];
  eeprom_read_block(magic, (const void *)ADDR_MAGIC, 4);
  bool formatted = magic[0] == 'F' && magic[1] == 'F' && magic[2] == LAYOUT_VERSION;
  if (!formatted) {
    // A new board, or one that ran something else: lay the map out once.
    defaults(settings);
    s_hdr = {0, {0, 0}, 0};
    for (uint16_t i = 0; i < 4; i++) eeprom_update_byte((uint8_t *)(ADDR_MAGIC + i), s_magic[i]);
    eeprom_update_block(&settings, (void *)ADDR_SETTINGS, sizeof(settings));
    eeprom_update_block(&s_hdr, (void *)ADDR_HEADER, sizeof(s_hdr));
    enqueue(nullptr, ADDR_LOGS, LOG_DAYS * sizeof(DayLog), T_PLAIN, 0xFF);
    return;
  }
  eeprom_read_block(&settings, (const void *)ADDR_SETTINGS, sizeof(settings));
  if (settings.version != SETTINGS_VERSION) {
    defaults(settings);
    saveSettings(settings);
  }
  if (settings.brightness > 2) settings.brightness = 2;
  if (settings.playMode >= PM_COUNT) settings.playMode = PM_ONCE;
  if (settings.presenceMin == 0 || settings.presenceMax <= settings.presenceMin) {
    settings.presenceMin = 20;
    settings.presenceMax = 90;
  }
  for (BotAlarm &a : settings.alarms) {
    if (a.hour > 23) a.hour = 7;
    if (a.minute > 59) a.minute = 0;
    if (a.tone >= 12) a.tone = 0;
    a.days &= 0x7F;
  }
  eeprom_read_block(&s_hdr, (const void *)ADDR_HEADER, sizeof(s_hdr));
  if (s_hdr.activeBank > 1) s_hdr = {0, {0, 0}, 0};
  if (s_hdr.count[0] > MAX_BLOCKS) s_hdr.count[0] = 0;
  if (s_hdr.count[1] > MAX_BLOCKS) s_hdr.count[1] = 0;
}

// --- routine ------------------------------------------------------------------

static uint16_t bankAddr(uint8_t bank) { return bank ? ADDR_BANK1 : ADDR_BANK0; }

uint8_t routineCount() { return s_writing ? s_stagingCount : s_hdr.count[s_hdr.activeBank]; }

bool routineWriting() { return s_writing; }

void readBlock(uint8_t index, uint8_t *out) {
  if (s_writing) {
    memcpy(out, s_staging + (uint16_t)index * BLOCK_SIZE, BLOCK_SIZE);
    return;
  }
  eeprom_read_block(out, (const void *)(bankAddr(s_hdr.activeBank) + (uint16_t)index * BLOCK_SIZE), BLOCK_SIZE);
}

void commitRoutine(const uint8_t *staging, uint8_t count) {
  s_staging = staging;
  s_stagingCount = count;
  s_writing = true;
  s_newBank = s_hdr.activeBank ? 0 : 1;
  if (count == 0) {
    Job j = {staging, 0, 0, 0, 0, 0, T_BANK, false};
    finished(j);
    return;
  }
  enqueue(staging, bankAddr(s_newBank), (uint16_t)count * BLOCK_SIZE, T_BANK);
}

// --- logs ---------------------------------------------------------------------

bool readLog(uint16_t date, DayLog &out) {
  eeprom_read_block(&out, (const void *)(ADDR_LOGS + (date % LOG_DAYS) * sizeof(DayLog)), sizeof(DayLog));
  return out.date == date;
}

void writeLog(const DayLog *log) {
  enqueue((const uint8_t *)log, ADDR_LOGS + (log->date % LOG_DAYS) * sizeof(DayLog), sizeof(DayLog), T_PLAIN);
}

}  // namespace Store
