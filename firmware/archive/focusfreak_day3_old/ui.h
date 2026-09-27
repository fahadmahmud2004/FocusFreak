#ifndef UI_H
#define UI_H

#include <Arduino.h>
#include <U8g2lib.h>
#include "face.h"

enum ScreenMode {
    SCREEN_FACE_DEMO,  // Fullscreen animated face
    SCREEN_AMBIENT,    // Clock / Status with mini face
    SCREEN_TASK        // Active Focus Session Timer
};

class UIManager {
public:
    UIManager(U8G2 &display, FaceRenderer &face);

    void init();
    void setMode(ScreenMode mode);
    ScreenMode getMode() const { return _currentMode; }

    void render();

private:
    U8G2 &_u8g2;
    FaceRenderer &_face;
    ScreenMode _currentMode;

    void renderFaceDemo();
    void renderAmbient();
    void renderTask();
};

#endif // UI_H
