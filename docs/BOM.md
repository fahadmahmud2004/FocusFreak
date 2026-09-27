# Bill of materials

Pin map and wiring: [`WIRING.md`](WIRING.md).

| # | Component | Interface | Qty | Role |
|---|---|---|---|---|
| 1 | Arduino Mega 2560 (16U2 USB) | MCU board | 1 | Central controller |
| 2 | 5 V 2 A DC adapter | Power | 1 | Main supply |
| 3 | 2.42" OLED, 128×64, 7-pin | SPI | 1 | UI: face, clock, timer, menus, games |
| 4 | SHT21 (GY-21) | I²C | 1 | Room temperature and humidity |
| 5 | DS3231 RTC + CR2032 | I²C | 1 | Timekeeping across power cuts |
| 6 | HC-SR04 | Trigger / Echo | 1 | Desk presence (20–90 cm) |
| 7 | LDR module | Analog | 1 | Ambient light |
| 8 | TTP223 capacitive touch | Digital | 3 | 2 on top (pat), 1 on front (poke) |
| 9 | Rotary encoder with push | CLK / DT / SW | 1 | Navigation and selection |
| 10 | Tactile push button | Digital | 1 | Menu / back |
| 11 | Active buzzer | Digital | 1 | Alarms |
| 12 | Passive buzzer | PWM (`tone()`) | 1 | Tunes and cues |
| 13 | HC-05 Bluetooth | UART (SPP) | 1 | Link to the phone app |
| 14 | SG90 micro servo | PWM | 1 | The wiggling ear |

**Extras:** 1 kΩ + 2 kΩ resistors (HC-05 RX voltage divider), 100 Ω resistor (passive buzzer), breadboard and ~45 jumper wires.
