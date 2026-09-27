#ifndef FACE_H
#define FACE_H

#include <Arduino.h>
#include <U8g2lib.h>

// Moods for the bot personality
enum Mood {
    MOOD_CALM,       // Default neutral, calm eyes
    MOOD_HAPPY,      // Happy curved/squinted eyes (e.g. after head pat or task done)
    MOOD_SAD,        // Drooped/sad eyelids (e.g. phone removed)
    MOOD_SLEEPY,     // Half-closed drowsy eyes
    MOOD_SEARCHING   // Wide searching eyes
};

// Gaze directions
enum Gaze {
    GAZE_CENTER,
    GAZE_LEFT,
    GAZE_RIGHT,
    GAZE_UP,
    GAZE_DOWN
};

class FaceRenderer {
public:
    FaceRenderer(U8G2 &display);

    void init();
    void update();          // Call this in the scheduler loop (e.g. every 40 ms)
    void render();          // Draws procedural eyes into U8g2 buffer

    void setMood(Mood mood);
    void setGaze(Gaze gaze);
    void triggerBlink();

    // Auto-blink controls
    void enableAutoBlink(bool enable) { _autoBlink = enable; }

private:
    U8G2 &_u8g2;

    Mood _currentMood;
    Gaze _currentGaze;

    // Eye base geometry
    int16_t _eyeWidth;
    int16_t _eyeHeight;
    int16_t _eyeRadius;
    int16_t _eyeGap;

    // Current animated eye parameters
    int16_t _currentWidth;
    int16_t _currentHeight;
    int16_t _gazeOffsetX;
    int16_t _gazeOffsetY;
    int16_t _targetGazeX;
    int16_t _targetGazeY;

    // Blink state
    bool _isBlinking;
    uint8_t _blinkStep;
    uint32_t _lastBlinkTime;
    uint32_t _nextBlinkInterval;
    bool _autoBlink;

    void processAnimation();
    void drawEye(int16_t cx, int16_t cy, int16_t w, int16_t h, int16_t r, Mood mood);
};

#endif // FACE_H
