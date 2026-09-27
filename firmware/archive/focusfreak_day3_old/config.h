#include <Wire.h>
#include <Adafruit_HTU21DF.h>

// Initialize HTU21D sensor instance
Adafruit_HTU21DF htu = Adafruit_HTU21DF();

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    delay(10); // Wait for Serial monitor to open
  }

  Serial.println(F("========================================"));
  Serial.println(F("     FocusFreak - HTU21D Sensor Test    "));
  Serial.println(F("========================================"));

  // Connect to the sensor via I2C (Address 0x40)
  if (!htu.begin()) {
    Serial.println(F("❌ ERROR: HTU21D sensor not found!"));
    Serial.println(F("Please check your wiring:"));
    Serial.println(F("  - VIN -> 5V"));
    Serial.println(F("  - GND -> GND"));
    Serial.println(F("  - SCL -> Pin 21 (SCL)"));
    Serial.println(F("  - SDA -> Pin 20 (SDA)"));
    while (1) {
      delay(1000);
    }
  }

  Serial.println(F("✅ SUCCESS: HTU21D sensor detected successfully!\n"));
}

void loop() {
  // Read temperature in Celsius
  float temp = htu.readTemperature();
  // Read relative humidity in %
  float humidity = htu.readHumidity();

  // Print results to Serial Monitor
  Serial.print(F("🌡️  Temperature: "));
  Serial.print(temp, 2);
  Serial.print(F(" °C   |   💧 Humidity: "));
  Serial.print(humidity, 2);
  Serial.println(F(" %"));

  // Read every 1 second
  delay(1000);
}