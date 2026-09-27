#include "drv_sensors.h"

SensorDriver::SensorDriver(uint8_t trigPin, uint8_t echoPin)
    : _trigPin(trigPin),
      _echoPin(echoPin),
      _rawDistanceCm(999),
      _filteredDistanceCm(999),
      _filterIndex(0),
      _sampleCount(0),
      _isPersonPresent(false),
      _presenceChanged(false),
      _consecutiveMatches(0) {
    for (uint8_t i = 0; i < FILTER_WINDOW_SIZE; i++) {
        _filterBuffer[i] = 999;
    }
}

void SensorDriver::init() {
    pinMode(_trigPin, OUTPUT);
    digitalWrite(_trigPin, LOW);
    pinMode(_echoPin, INPUT);
}

void SensorDriver::update() {
    // 1. Generate 10 microsecond trigger pulse
    digitalWrite(_trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(_trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(_trigPin, LOW);

    // 2. Measure Echo pulse width with bounded timeout (<= 6000 us)
    uint32_t duration = pulseIn(_echoPin, HIGH, SENSOR_ECHO_TIMEOUT_US);

    if (duration == 0) {
        // Echo timed out -> object is farther than ~100 cm or no obstacle
        _rawDistanceCm = 999;
    } else {
        // Distance in cm = (duration_us / 2) / 29.1 (or duration * 0.0343 / 2)
        _rawDistanceCm = (uint16_t)(duration / 58.2);
    }

    // 3. Store in circular buffer for median filter
    _filterBuffer[_filterIndex] = _rawDistanceCm;
    _filterIndex = (_filterIndex + 1) % FILTER_WINDOW_SIZE;
    if (_sampleCount < FILTER_WINDOW_SIZE) {
        _sampleCount++;
    }

    // 4. Compute Median-of-5
    _filteredDistanceCm = computeMedian();

    // 5. Update Presence State with Hysteresis
    updatePresenceState(_filteredDistanceCm);
}

uint16_t SensorDriver::computeMedian() {
    uint16_t temp[FILTER_WINDOW_SIZE];
    uint8_t validCount = 0;

    // Collect valid non-out-of-range readings first
    for (uint8_t i = 0; i < _sampleCount; i++) {
        if (_filterBuffer[i] < 400) { // Valid readings under 4 meters
            temp[validCount++] = _filterBuffer[i];
        }
    }

    if (validCount == 0) {
        return 999; // Truly out of range
    }

    // Sort valid readings
    for (uint8_t i = 1; i < validCount; i++) {
        uint16_t key = temp[i];
        int8_t j = i - 1;
        while (j >= 0 && temp[j] > key) {
            temp[j + 1] = temp[j];
            j--;
        }
        temp[j + 1] = key;
    }

    return temp[validCount / 2];
}

void SensorDriver::updatePresenceState(uint16_t distance) {
    bool previousState = _isPersonPresent;

    // Count how many recent samples in our 5-sample window indicate someone is close
    uint8_t closeVotes = 0;
    for (uint8_t i = 0; i < _sampleCount; i++) {
        if (_filterBuffer[i] <= DISTANCE_APPROACH_CM) {
            closeVotes++;
        }
    }

    if (!_isPersonPresent) {
        // User approaches if at least 2 out of 5 recent samples are < 60 cm
        if (closeVotes >= 2) {
            _isPersonPresent = true;
        }
    } else {
        // User leaves only if close votes drop to 0 (no close readings at all in recent history)
        if (closeVotes == 0 && distance >= DISTANCE_LEAVE_CM) {
            _isPersonPresent = false;
        }
    }

    if (previousState != _isPersonPresent) {
        _presenceChanged = true;
    }
}
