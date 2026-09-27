#ifndef DRV_SENSORS_H
#define DRV_SENSORS_H

#include <Arduino.h>
#include "config.h"

#define FILTER_WINDOW_SIZE 5

class SensorDriver {
public:
    SensorDriver(uint8_t trigPin = PIN_TRIG, uint8_t echoPin = PIN_ECHO);

    void init();
    void update(); // Called at 10 Hz (every 100 ms)

    uint16_t getFilteredDistanceCm() const { return _filteredDistanceCm; }
    uint16_t getRawDistanceCm() const { return _rawDistanceCm; }
    bool isPersonPresent() const { return _isPersonPresent; }
    bool hasPresenceChanged() {
        bool changed = _presenceChanged;
        _presenceChanged = false;
        return changed;
    }

private:
    uint8_t _trigPin;
    uint8_t _echoPin;

    uint16_t _rawDistanceCm;
    uint16_t _filteredDistanceCm;
    uint16_t _filterBuffer[FILTER_WINDOW_SIZE];
    uint8_t  _filterIndex;
    uint8_t  _sampleCount;

    bool _isPersonPresent;
    bool _presenceChanged;
    uint8_t _consecutiveMatches;

    uint16_t computeMedian();
    void updatePresenceState(uint16_t distance);
};

#endif // DRV_SENSORS_H
