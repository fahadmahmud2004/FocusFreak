// The SG90 servo ear on the back of the head. Pet the bot and it wiggles.
//
// The servo is attached only while it moves: a held SG90 hums, jitters and
// draws current for nothing, so after each wiggle it is detached and goes
// quiet at the centre position.
#pragma once
#include <Arduino.h>

namespace Ear {

void begin();
void update();
void wiggle();

}  // namespace Ear
