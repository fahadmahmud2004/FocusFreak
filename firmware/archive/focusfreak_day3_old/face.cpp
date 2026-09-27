#include "face.h"

FaceRenderer::FaceRenderer(U8G2 &display)
    : _u8g2(display),
      _currentMood(MOOD_CALM),
      _currentGaze(GAZE_CENTER),
      _eyeWidth(28),
      _eyeHeight(34),
      _eyeRadius(7),
      _eyeGap(16),
      _currentWidth(28),
      _currentHeight(34),
      _gazeOffsetX(0),
      _gazeOffsetY(0),
      _targetGazeX(0),
      _targetGazeY(0),
      _isBlinking(false),
      _blinkStep(0),
      _lastBlinkTime(0),
      _nextBlinkInterval(3000),
      _autoBlink(true) {}

void FaceRenderer::init() {
    _lastBlinkTime = millis();
    _nextBlinkInterval = random(2500, 5000);
}

void FaceRenderer::setMood(Mood mood) {
    _currentMood = mood;
}

void FaceRenderer::setGaze(Gaze gaze) {
    _currentGaze = gaze;
    switch (gaze) {
        case GAZE_CENTER:
            _targetGazeX = 0;
            _targetGazeY = 0;
            break;
        case GAZE_LEFT:
            _targetGazeX = -9;
            _targetGazeY = 0;
            break;
        case GAZE_RIGHT:
            _targetGazeX = 9;
            _targetGazeY = 0;
            break;
        case GAZE_UP:
            _targetGazeX = 0;
            _targetGazeY = -6;
            break;
        case GAZE_DOWN:
            _targetGazeX = 0;
            _targetGazeY = 6;
            break;
    }
}

void FaceRenderer::triggerBlink() {
    if (!_isBlinking) {
        _isBlinking = true;
        _blinkStep = 0;
    }
}

void FaceRenderer::update() {
    // 1. Smooth gaze interpolation
    if (_gazeOffsetX < _targetGazeX) _gazeOffsetX++;
    else if (_gazeOffsetX > _targetGazeX) _gazeOffsetX--;

    if (_gazeOffsetY < _targetGazeY) _gazeOffsetY++;
    else if (_gazeOffsetY > _targetGazeY) _gazeOffsetY--;

    // 2. Auto-blink timer
    uint32_t now = millis();
    if (_autoBlink && !_isBlinking && (now - _lastBlinkTime >= _nextBlinkInterval)) {
        triggerBlink();
        _lastBlinkTime = now;
        _nextBlinkInterval = random(2500, 5500);
    }

    // 3. Blink animation state machine
    if (_isBlinking) {
        // Blink frames: Closing (steps 0..2) -> Closed (step 3) -> Opening (steps 4..6)
        _blinkStep++;
        if (_blinkStep <= 3) {
            // Closing eye
            int16_t stepH = (_eyeHeight - 3) / 3;
            _currentHeight = _eyeHeight - (_blinkStep * stepH);
            if (_currentHeight < 3) _currentHeight = 3;
        } else if (_blinkStep <= 6) {
            // Opening eye
            uint8_t openStep = _blinkStep - 3;
            int16_t stepH = (_eyeHeight - 3) / 3;
            _currentHeight = 3 + (openStep * stepH);
            if (_currentHeight > _eyeHeight) _currentHeight = _eyeHeight;
        } else {
            // Blink finished
            _isBlinking = false;
            _currentHeight = _eyeHeight;
            _blinkStep = 0;
        }
    } else {
        if (_currentMood == MOOD_SLEEPY) {
            _currentHeight = _eyeHeight / 2;
        } else if (_currentMood == MOOD_SEARCHING) {
            _currentHeight = _eyeHeight + 4;
        } else {
            _currentHeight = _eyeHeight;
        }
    }
}

void FaceRenderer::render() {
    int16_t screenCenterX = 64 + _gazeOffsetX;
    int16_t screenCenterY = 32 + _gazeOffsetY;

    int16_t leftEyeCenterX = screenCenterX - (_eyeWidth / 2) - (_eyeGap / 2);
    int16_t rightEyeCenterX = screenCenterX + (_eyeWidth / 2) + (_eyeGap / 2);

    // Render left and right eyes
    drawEye(leftEyeCenterX, screenCenterY, _currentWidth, _currentHeight, _eyeRadius, _currentMood);
    drawEye(rightEyeCenterX, screenCenterY, _currentWidth, _currentHeight, _eyeRadius, _currentMood);
}

void FaceRenderer::drawEye(int16_t cx, int16_t cy, int16_t w, int16_t h, int16_t r, Mood mood) {
    int16_t x = cx - (w / 2);
    int16_t y = cy - (h / 2);

    // Keep radius in bounds
    if (r > h / 2) r = h / 2;
    if (r > w / 2) r = w / 2;
    if (r < 1) r = 1;

    // Base eye body
    _u8g2.drawRBox(x, y, w, h, r);

    // Mood-specific eye shaping
    if (mood == MOOD_HAPPY && !_isBlinking) {
        // Cut out the lower half to make happy squinting "^" crescent eyes
        int16_t cutHeight = h / 2 + 2;
        _u8g2.setDrawColor(0); // Erase
        _u8g2.drawBox(x - 1, cy, w + 2, cutHeight);
        _u8g2.setDrawColor(1); // Restore
    } else if (mood == MOOD_SAD && !_isBlinking) {
        // Cut an angled line at the top to give a droopy sad expression
        _u8g2.setDrawColor(0); // Erase
        // Slanted eyebrow cutout
        _u8g2.drawLine(x, y + 2, x + w - 1, y + 8);
        _u8g2.drawLine(x, y + 1, x + w - 1, y + 7);
        _u8g2.drawLine(x, y, x + w - 1, y + 6);
        _u8g2.setDrawColor(1); // Restore
    }
}
