# FocusFreak — Final Wiring Guide (Arduino Mega 2560)

This is the **final, frozen** pin map. Wire it once, close the box, and from then on
everything is done in code. Every component gets its own dedicated pin, so any
firmware can use any component at any time.

The pin numbers also live in [`firmware/hardware_test/pins.h`](../firmware/hardware_test/pins.h).
**Copy that file into every sketch** so code and wiring always match.

---

## 0. Before you start

**Extra parts you need (not in the BOM):**

| Part | Qty | Used for |
|---|---|---|
| 1 kΩ resistor | 1 | HC-05 voltage divider (**required**) |
| 2 kΩ resistor (2.2 kΩ is fine too) | 1 | HC-05 voltage divider (**required**) |
| 100 Ω resistor | 1 | Passive buzzer (recommended) |
| Male-female + male-male jumper wires | ~45 | Everything |

> No 2 kΩ resistor? Put **two 1 kΩ in series** instead. Three 1 kΩ resistors cover the whole divider.

**Checklist:**
- [ ] **Unplug the USB cable and the adapter.** Wire with the power OFF, always.
- [ ] **Take out the black IC chip on the breadboard.** It isn't in the BOM and nothing below uses it. Leave it in and it can short the rails.
- [ ] **Check the breadboard's power rails.** On many breadboards the red/blue rails are **split in the middle** (look for a gap in the red line). If yours is split, bridge the two halves with a short jumper, on both rails.

---

## 1. Power setup: 5V barrel adapter → breadboard rail → Mega 5V pin

A 5V adapter in the barrel jack alone is **not enough**. The jack feeds the Mega's regulator, which
needs 7V+, so the board would only get ~3.5–4V. The fix is to take the adapter's 5V **straight to the
breadboard rail**, and feed the Mega from that rail through its **5V pin**, skipping the regulator.

```
 5V adapter plug ──► Mega barrel jack
                        │ (wires soldered to the jack's + and − pins underneath)
                        ├── + ──►  Breadboard RED rail  ──►  Mega 5V pin  +  all module VCCs
                        └── − ──►  Breadboard BLUE rail ──►  Mega GND pin(s)  +  all module GNDs
```

> **Cleaner alternative (optional):** a separate **female DC jack with screw terminals** (costs very little)
> mounted in the box hole does exactly the same job with **no soldering on the Mega**. Wire it to the
> rails the same way and leave the Mega's own barrel jack empty.

### ⚠ The Mega's 5V pin has NO protection. Before connecting that wire to the Mega, check these 3 things with a multimeter

Plug in the adapter with the rail wires **not yet connected to the Mega**, and measure between the RED and BLUE rail:

| Check | Must be | If not |
|---|---|---|
| **Polarity** | Meter shows **+5.x V** (not −5V) with red probe on RED rail | Swap your two soldered wires. Reversed polarity on the 5V pin **kills the Mega instantly** |
| **Voltage** | Between **4.8V and 5.3V** | Above 5.5V: don't use this adapter (the chip's max is 6V). Cheap unregulated adapters often read 6–8V |
| **Which jack pins** | Find the two soldered points that give that 5V reading | The Mega jack has 3 legs. Only 2 of them are + and −. The multimeter tells you which |

### The golden rules

1. **Adapter OR USB, never both at the same time.** When you burn code, **unplug the adapter first**, then plug in
   USB. USB alone powers everything except a hard-working servo (~300 mA without servo, USB gives 500 mA).
   The servo can push it over, see 3.11. If both are plugged in together, the adapter pushes current back into your laptop's USB port.
2. **Don't use the Mega's VIN pin for anything.** With a 5V adapter in the jack it sits at ~4.3V.
3. **All GNDs connect together** (breadboard blue rail).
4. **Never use D0 / D1.** Those are the USB serial lines used for code upload.
5. **Wire with the power OFF**, always.

---

## 2. Step 1 — Power rails (do this first)

```
 Adapter +  (soldered wire) ──►  Breadboard RED rail  (+5V)
 Adapter −  (soldered wire) ──►  Breadboard BLUE rail (GND)
 Mega  5V   ◄──────────────────  Breadboard RED rail
 Mega  GND  ◄──────────────────  Breadboard BLUE rail
 Mega  GND  ◄──────────────────  Breadboard BLUE rail (second GND wire, for better ground)
```

When running on **USB** (adapter unplugged) this still works: the Mega then powers the rail through the same 5V wire.

Every **VCC / VIN / +** pin below goes to the **RED rail**. Every **GND / −** goes to the **BLUE rail**.

Also make **two I2C rows** on the breadboard (any two empty 5-hole rows):

```
 Mega D20 (SDA) ──► "SDA row"      ← RTC SDA + SHT21 SDA also go here
 Mega D21 (SCL) ──► "SCL row"      ← RTC SCL + SHT21 SCL also go here
```

> On the Mega, D20/D21 are labelled **SDA 20 / SCL 21** near the TX/RX pins. The two
> pins marked SDA/SCL next to AREF are the **same** signals, so either one works.

---

## 3. Step 2 — Wire each component

Tick each row as you go. **"Mega pin"** = the number printed on the Mega header.

### 3.1 2.42" OLED display (7 pins, SPI)

| OLED pin | Goes to | ✓ |
|---|---|---|
| GND | BLUE rail | ☐ |
| VCC | RED rail (5V) | ☐ |
| **SCK** (some boards print SCL, D0 or CLK — same pin) | **Mega D52** | ☐ |
| **SDA** (some boards print MOSI, D1 or DIN — same pin) | **Mega D51** | ☐ |
| RES (or RST) | **Mega D49** | ☐ |
| DC | **Mega D47** | ☐ |
| CS | **Mega D48** | ☐ |

> D50–D53 sit at the far end of the Mega's double header (bottom-right pair of pins).

### 3.2 RTC module (DS3231: 32K, SQW, SCL, SDA, VCC, GND)

Use the **6-pin side**.

| RTC pin | Goes to | ✓ |
|---|---|---|
| GND | BLUE rail | ☐ |
| VCC | RED rail | ☐ |
| SDA | SDA row (→ D20) | ☐ |
| SCL | SCL row (→ D21) | ☐ |
| SQW | **Mega D2** (1-second tick / alarm interrupt) | ☐ |
| 32K | *leave empty* | — |

> **Battery warning (ZS-042 DS3231 boards):** this board tries to *charge* the coin cell at 5V.
> With a normal **CR2032** (non-rechargeable) that can swell the battery over time. Two fixes: use an
> **LIR2032** (rechargeable), or ask someone with a soldering iron to remove the tiny resistor
> marked **201** next to the battery. Everything works either way. This only affects the battery's life.

### 3.3 SHT21 temperature/humidity (GY-21: VIN, GND, SCL, SDA)

| SHT21 pin | Goes to | ✓ |
|---|---|---|
| VIN | RED rail (5V) | ☐ |
| GND | BLUE rail | ☐ |
| SCL | SCL row (→ D21) | ☐ |
| SDA | SDA row (→ D20) | ☐ |

### 3.4 HC-SR04 ultrasonic (VCC, Trig, Echo, GND)

| HC-SR04 pin | Goes to | ✓ |
|---|---|---|
| VCC | RED rail | ☐ |
| Trig | **Mega D22** | ☐ |
| Echo | **Mega D24** | ☐ |
| GND | BLUE rail | ☐ |

### 3.5 HC-05 Bluetooth (the only tricky one, go slow)

HC-05's **RXD** pin only tolerates **3.3V**, and the Mega outputs 5V. So the Mega → HC-05 wire
goes through a **voltage divider** (5V → ~3.3V). The other direction needs nothing.

| HC-05 pin | Goes to | ✓ |
|---|---|---|
| VCC | RED rail (5V — the module has its own regulator) | ☐ |
| GND | BLUE rail | ☐ |
| TXD | **Mega D17 (RX2)** — direct wire | ☐ |
| RXD | Middle of the divider (see drawing) | ☐ |
| STATE | **Mega D26** (HIGH when a phone is connected) | ☐ |
| EN / KEY | *leave empty* | — |

**Voltage divider on the breadboard** (uses one empty breadboard row, "row X"):

```
 Mega D16 (TX2) ──[ 1 kΩ ]──┬── row X ──► HC-05 RXD
                            │
                         [ 2 kΩ ]
                            │
                        BLUE rail (GND)
```

Plainly: one leg of the **1 kΩ** in the D16 wire, other leg in **row X**. One leg of the **2 kΩ** in
**row X**, other leg in the **BLUE rail**. HC-05 RXD wire also goes into **row X**.

> ⚠ Easy mistake: the Mega's **TX2 (D16)** goes to the HC-05's **RXD**, and HC-05 **TXD** goes to
> Mega **RX2 (D17)**. TX always goes to RX. Also don't mix up the 1 kΩ and 2 kΩ positions.

### 3.6 LDR light sensor (bare 2-leg LDR + your resistor = 3 wires)

A bare LDR only changes its resistance with light, so it needs a partner resistor to make a readable voltage
(a "voltage divider"). You've already soldered that, so you have **3 wires: two ends + the middle joint**.

```
 RED rail (5V) ──── LDR ────┬──── resistor ──── BLUE rail (GND)
                            │
                        Mega A8   (the middle joint, where LDR and resistor meet)
```

| Wire | Goes to | ✓ |
|---|---|---|
| Free end of the **LDR** | RED rail (5V) | ☐ |
| Free end of the **resistor** | BLUE rail (GND) | ☐ |
| **Middle** joint (LDR + resistor) | **Mega A8** | ☐ |

Wired like this: **more light = higher reading** (0–1023). If you connect the two ends the other way round
(LDR to GND, resistor to 5V), it's still completely safe. The reading just flips (more light = lower), and code can handle that.

> Best resistor value is **10 kΩ** (anything 4.7k–47k works). If the reading barely changes between a dark room and
> a lamp, the resistor value is too far off. Tell me what value you used.
> ⚠ The only wrong wiring is the **middle joint going to a rail**. The middle wire must go **only to A8**.

### 3.7 Touch sensors ×3 (TTP223: VCC, I/O or SIG, GND)

| Sensor | VCC | GND | I/O (SIG) → | ✓ |
|---|---|---|---|---|
| Top-Left | RED rail | BLUE rail | **Mega D28** | ☐ |
| Top-Right | RED rail | BLUE rail | **Mega D30** | ☐ |
| Front | RED rail | BLUE rail | **Mega D42** | ☐ |

### 3.8 Rotary encoder

**If it's on a small board (KY-040, pins: CLK, DT, SW, +, GND):**

| Encoder pin | Goes to | ✓ |
|---|---|---|
| CLK | **Mega D18** | ☐ |
| DT | **Mega D19** | ☐ |
| SW | **Mega D32** | ☐ |
| + | RED rail | ☐ |
| GND | BLUE rail | ☐ |

**If it's a bare encoder (3 legs on one side, 2 on the other):**
3-leg side: left → **D18**, middle → **BLUE rail**, right → **D19**.
2-leg side: one → **D32**, other → **BLUE rail**. (No 5V needed. The code turns on internal pull-ups.)

> If it counts in the wrong direction later, just swap the D18/D19 numbers in `pins.h`. No rewiring needed.

### 3.9 Push button

| Button leg | Goes to | ✓ |
|---|---|---|
| Leg 1 | **Mega D34** | ☐ |
| Leg 2 | BLUE rail | ☐ |

> 4-leg tactile button? Use two **diagonally opposite** legs. That pair is always correct.
> No resistor needed (the code uses `INPUT_PULLUP`: not pressed = HIGH, pressed = LOW).

### 3.10 Buzzers

**How to tell them apart:** the **active** buzzer has a sealed, smooth bottom (often a white sticker on
top). The **passive** buzzer shows a green circuit board on the bottom. The **longer leg / "+" mark** is positive.

| Buzzer | + leg | − leg | ✓ |
|---|---|---|---|
| Passive | **Mega D38** through a **100 Ω** resistor | BLUE rail | ☐ |
| Active | **Mega D40** (direct) | BLUE rail | ☐ |

> If a buzzer is on a 3-pin board (VCC, GND, I/O): VCC → RED rail, GND → BLUE rail, I/O → the same
> Mega pin as above. Some of these boards are "low-level trigger" (beep on LOW). The test sketch shows which type you have.

### 3.11 SG90 servo motor (the "ear", 3 wires)

Mounted on the side/back of the head. When the top touch sensor is patted, code turns the servo back and
forth so it looks like the robot is **wiggling its ear**.

**Wire colours** (SG90 standard): **Brown = GND**, **Red = +5V**, **Orange = Signal**.
(Some servos use Black / Red / White instead. Then black = GND, red = +5V, white = signal.)

| Servo wire | Goes to | ✓ |
|---|---|---|
| **Brown** (GND) | BLUE rail | ☐ |
| **Red** (+5V) | RED rail, **close to the big electrolytic capacitor** (see 3.12) | ☐ |
| **Orange** (Signal) | **Mega D45** | ☐ |

The servo plug is a female 3-hole connector. Push male-male jumpers into it, and wrap it with tape so the
jumpers can't slip out when the ear moves.

> ⚠ **Power: the most important part of the servo.** The servo draws **100–250 mA while moving** and up to
> **~700 mA if it's blocked** (e.g. the ear hits the box). So:
> - **Red wire goes to the breadboard RED rail, never to a Mega pin.** In this build the rail is fed straight from
>   the adapter, so the servo gets full adapter current and doesn't go through the Mega.
> - The **big electrolytic capacitor** (470 µF+) on the rail next to the servo wires is now **required**, not optional.
>   Without it every servo move dips the 5V, and the Mega or OLED can reset or glitch.
> - **On USB power** (while uploading code) small ear wiggles usually work. If the Mega resets or the USB
>   disconnects when the servo moves, that's USB's 500 mA limit, not a wiring fault. Test the servo on the adapter.

**Attach the ear at the centre position (do this in order):**
1. Take the plastic horn off the servo shaft (it just pulls off).
2. Upload the test sketch. On every boot it moves the servo to **90° (centre)** and then releases it.
3. Now push the horn/ear back on, pointing in the ear's **neutral** direction.
4. Pat the top touch sensor. The ear wiggles between 60° and 120°. If it hits the box, make the range smaller
   with `SERVO_EAR_MIN` / `SERVO_EAR_MAX` in `pins.h`.

> **Code notes:** use the built-in **Servo** library. On the Mega it uses Timer5, so **D44, D45, D46 lose
> `analogWrite()` PWM**. Nothing else in this build uses PWM there, so there's no conflict with the buzzers or the display.
> After a move, call `servo.detach()`. The servo then stops humming and jittering and uses almost no power.
> Never command 0° or 180° with the ear mounted. At the ends the gears strain, which is the ~700 mA case.

### 3.12 Capacitors (big one required because of the servo, all on the breadboard)

Capacitors act like tiny **backup batteries** on the power rail. When the servo moves, the buzzer starts, the HC-05 pairs
or the OLED goes bright, current jumps suddenly. Without capacitors the 5V dips for a split second, which can
reset the Mega or make sensor readings jumpy. None of these touch the Mega's pins.

**How to read them:**
- **Electrolytic** (tall can, e.g. "470µF 16V"): **has polarity**. The **long leg = +**, and the side with the
  **stripe (−)** is minus. The voltage printed on it must be **10V or more**. ⚠ If you put it in backwards it can
  **pop/burst**. Double-check before powering on.
- **Ceramic** (small flat disc/blob, code like **104**): no polarity, either way is fine. **104 = 100 nF**.

| Capacitor | Where | Legs | ✓ |
|---|---|---|---|
| **Big electrolytic** (470–1000 µF) — **required** | Across the rails, right next to where the **servo's red/brown wires** plug in | **+ → RED rail**, **− → BLUE rail** | ☐ |
| **Second electrolytic** (100–470 µF) | Across the rails, right where the adapter wires enter | **+ → RED rail**, **− → BLUE rail** | ☐ |
| **Electrolytic 10–100 µF** | Across the rails near the HC-05 | **+ → RED**, **− → BLUE** | ☐ |
| **Ceramic 104 (100 nF)** | Across the rails near the OLED | either way, RED ↔ BLUE | ☐ |
| **Ceramic 104 (100 nF)** | Across the rails near the HC-SR04 | either way, RED ↔ BLUE | ☐ |

> Don't have exactly these values? Any electrolytic **100 µF or bigger** works as the big one, and any ceramic
> between **10 nF (103) and 1 µF (105)** works as a small one. More capacitors on the rail never hurt.
> Only have one big capacitor? Put it next to the servo wires. Leftover caps just stay in the parts box.

---

## 4. Master pin table (the one-page summary)

| Mega pin | Component | Module pin | Code type |
|---|---|---|---|
| **D2** | RTC | SQW | Input, interrupt (1 Hz tick) |
| **D16** (TX2) | HC-05 | RXD *(via 1k/2k divider)* | `Serial2` |
| **D17** (RX2) | HC-05 | TXD | `Serial2` |
| **D18** | Rotary encoder | CLK | Input, interrupt |
| **D19** | Rotary encoder | DT | Input, interrupt |
| **D20** (SDA) | RTC + SHT21 | SDA | `Wire` (I2C) |
| **D21** (SCL) | RTC + SHT21 | SCL | `Wire` (I2C) |
| **D22** | HC-SR04 | Trig | Output |
| **D24** | HC-SR04 | Echo | Input (`pulseIn`) |
| **D26** | HC-05 | STATE | Input |
| **D28** | Touch Top-Left | I/O | Input |
| **D30** | Touch Top-Right | I/O | Input |
| **D32** | Rotary encoder | SW | `INPUT_PULLUP` |
| **D34** | Push button | leg | `INPUT_PULLUP` |
| **D38** | Passive buzzer | + (via 100 Ω) | `tone()` |
| **D40** | Active buzzer | + | Output HIGH/LOW |
| **D42** | Touch Front | I/O | Input |
| **D45** | SG90 servo (ear) | Orange (signal) | `Servo` library |
| **D47** | OLED | DC | U8g2 |
| **D48** | OLED | CS | U8g2 |
| **D49** | OLED | RES | U8g2 |
| **D51** (MOSI) | OLED | SDA / MOSI / D1 | Hardware SPI |
| **D52** (SCK) | OLED | SCK / SCL / D0 | Hardware SPI |
| **D53** (SS) | — *(nothing connected)* | — | Must be OUTPUT in code |
| **A8** | LDR | middle joint (LDR + resistor) | `analogRead` (higher = brighter) |
| **D0, D1** | ⛔ USB — never connect | | |

**I2C addresses on the bus:** SHT21 = `0x40`, DS3231 = `0x68`, RTC board's EEPROM = `0x57`. No conflicts.

**Free for future add-ons:** D3–D13 (all PWM-capable), D14/D15 (`Serial3`), D23, D25, D27, D29, D31,
D33, D35, D36, D37, D39, D41, D43, D44, D46, D50 (only if you never add a second SPI device), A0–A7, A9–A15.
(D44 and D46 still work as normal digital pins, but have no PWM while the Servo library is in use.)

---

## 5. Wire count check

When you're done, count the wires plugged **into the Mega headers**. There should be exactly **27**:

- Power: 5V ×1, GND ×2 = **3**
- Signals: D2, D16 *(to resistor)*, D17, D18, D19, D20, D21, D22, D24, D26, D28, D30, D32, D34,
  D38 *(to resistor)*, D40, D42, D45, D47, D48, D49, D51, D52, A8 = **24**

3 + 24 = **27**. If your count is off, a wire is missing or doubled.
(The servo's red/brown wires go to the breadboard rails, not the Mega, so they aren't counted. D20/D21 go to the breadboard SDA/SCL rows, not straight to both modules, so each one counts once.)

---

## 6. First power-on (in this order)

1. Double-check: **no wire touches D0/D1**, **no wire from RED rail to BLUE rail** directly.
2. Do the 3 multimeter checks from section 1 if you haven't yet. Then plug in the **adapter**. The Mega's **ON LED** should light, and the HC-05 LED should blink fast.
   If the Mega's LED is **off or dim**, or anything gets **hot**, unplug immediately. Something is shorted.
3. **Unplug the adapter**, connect USB, and upload [`firmware/hardware_test/hardware_test.ino`](../firmware/hardware_test/hardware_test.ino)
   (Tools → Board → **Arduino Mega or Mega 2560**). You can keep testing on USB, or unplug USB and run on the adapter.
4. Open Serial Monitor at **115200 baud**. Touch/turn/press every input and watch it react.
   The OLED shows all readings live.

**Libraries to install** (Arduino IDE → Library Manager): **U8g2** (by olikraus), **RTClib** (by Adafruit),
**Adafruit HTU21DF**, **Servo** (by Arduino).

---

## 7. If something doesn't work

| Symptom | Most likely cause |
|---|---|
| OLED blank | SCK/SDA swapped (D52 ↔ D51), or DC/CS/RES in the wrong pins |
| I2C scan finds nothing | SDA/SCL swapped, or the SDA/SCL row isn't connected to D20/D21 |
| Finds 0x68 but not 0x40 | SHT21 wire loose (or vice versa) |
| Distance always "no echo" | Trig/Echo swapped |
| Bluetooth pairs but no data | TXD/RXD swapped, or divider wired wrong. HC-05 default PIN is `1234` or `0000`, baud **9600** |
| Touch always "pressed" | VCC/GND swapped on that sensor. Unplug right away |
| Encoder jumps randomly | CLK/DT loose, or the GND wire of the encoder is missing |
| Button always pressed | Used two legs that are internally connected. Use diagonal legs |
| Light reading stuck at 0 or 1023 | Middle LDR wire isn't on A8, or a joint in your soldered LDR/resistor came loose |
| Servo doesn't move | Orange wire not on D45, or the brown wire isn't on GND |
| Mega resets / OLED glitches when the servo moves | Missing big capacitor next to the servo, or you're on USB. Try the adapter |
| Servo hums or shakes when it should be still | Code didn't call `detach()` after moving, or the ear is pushing against the box |
| Mega resets when buzzer beeps / BT pairs | Power dip. Add the electrolytic caps from 3.12 |
| Nothing works, Mega reboots | Short between 5V and GND somewhere |

---

## 8. Power budget (for reference)

| Part | Peak current |
|---|---|
| Mega 2560 | ~90 mA |
| OLED (full white) | ~55 mA |
| HC-05 (pairing) | ~50 mA |
| Active + passive buzzer together | ~50 mA |
| HC-SR04 | ~20 mA |
| Everything else | ~15 mA |
| SG90 servo (moving / blocked) | ~250 mA / ~700 mA |
| **Total without servo** | **~280 mA** (fine on USB's 500 mA) |
| **Total, servo moving** | **~530 mA** (over USB's limit → use the adapter) |
| **Worst case, servo blocked** | **~1 A** (still only half of the 5V 2A adapter) |
