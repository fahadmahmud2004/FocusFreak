// What BotOS asks the rest of the firmware to do: the `BotEffect`s of the
// Dart BotOS that are not sound (BotOS drives sound.h itself). Implemented in
// focusfreak.ino.
#pragma once
#include <Arduino.h>

// The focus timer and routines, run by session.cpp.
void hostStartFocus(uint16_t minutes);
void hostStartRoutine(uint8_t templateIndex);
void hostPauseFocus();
void hostResumeFocus();
void hostSkipBlock();
void hostStopFocus();

// Settings changed: persist them.
void hostSaveSettings();

// The head was petted or the bot laughed: wiggle the servo ear.
void hostEarWiggle();
