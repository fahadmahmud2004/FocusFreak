#include "ui.h"

UIManager::UIManager(U8G2 &display, FaceRenderer &face)
    : _u8g2(display), _face(face), _currentMode(SCREEN_FACE_DEMO) {}

void UIManager::init() {
    _face.init();
}

void UIManager::setMode(ScreenMode mode) {
    _currentMode = mode;
}

void UIManager::render() {
    _u8g2.clearBuffer();

    switch (_currentMode) {
        case SCREEN_FACE_DEMO:
            renderFaceDemo();
            break;
        case SCREEN_AMBIENT:
            renderAmbient();
            break;
        case SCREEN_TASK:
            renderTask();
            break;
    }

    _u8g2.sendBuffer();
}

void UIManager::renderFaceDemo() {
    // Render the full expressive procedural face
    _face.render();
}

void UIManager::renderAmbient() {
    // Top bar / header
    _u8g2.setFont(u8g2_font_helvB08_tr);
    _u8g2.drawStr(2, 10, "FOCUSFREAK");
    _u8g2.drawHLine(0, 12, 128);

    // Big Clock placeholder
    _u8g2.setFont(u8g2_font_logisoso16_tr);
    _u8g2.drawStr(4, 38, "09:45");

    _u8g2.setFont(u8g2_font_6x10_tr);
    _u8g2.drawStr(4, 52, "Next: Deep Work");

    // Mini face or status icon on right
    _u8g2.drawFrame(92, 18, 32, 40);
    _u8g2.drawDisc(102, 34, 3);
    _u8g2.drawDisc(114, 34, 3);
}

void UIManager::renderTask() {
    // Task Mode Layout
    _u8g2.setFont(u8g2_font_6x10_tr);
    _u8g2.drawStr(2, 10, "FOCUS: MATH SOLVE");
    _u8g2.drawHLine(0, 12, 128);

    // Countdown Timer
    _u8g2.setFont(u8g2_font_logisoso24_tr);
    _u8g2.drawStr(18, 44, "24:50");

    // Progress bar at bottom
    _u8g2.drawFrame(4, 54, 120, 7);
    _u8g2.drawBox(6, 56, 40, 3); // 33% progress
}
