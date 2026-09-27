// The buzzers. RTTTL melodies on the passive buzzer, played note by note
// without blocking the loop; short tones for clicks and games; the active
// buzzer pulsing under an alarm so it is heard across a room.
#pragma once
#include <Arduino.h>

#include "assets.h"

namespace Sound {

void begin();
void update();

// Starts a melody from PROGMEM. [audible] false runs the timeline silently
// (sound off in settings: the player's visualiser still moves). [alarm]
// adds the active buzzer.
void play(const MelodyDef *def, bool audible, bool alarm = false);
void stopMelody();

// Time since the melody started and its full length, in ms.
uint32_t elapsedMs();
uint32_t lengthMs();
// The note sounding now, 0 for a rest or nothing.
uint16_t currentHz();

// A short tone for clicks and game sounds. One buzzer: it cuts into a
// melody note, and the melody carries on with its next note.
void tone(uint16_t hz, uint16_t ms);

// Block cues played outside BotOS's music player. Skipped while a melody
// plays; true when it played.
bool cue(const MelodyDef *def);
bool busy();

void stopAll();

}  // namespace Sound
