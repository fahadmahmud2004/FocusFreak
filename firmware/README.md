# FocusFreak firmware — how to use it

| Folder | What it is |
|---|---|
| `focusfreak/` | **The real firmware.** Flash this one. |
| `hardware_test/` | Checks every part after wiring. Flash it only when something seems broken. |
| `archive/` | The old Day 3 sketch, kept for reference. Do not flash. |

Wiring: [`../docs/WIRING.md`](../docs/WIRING.md).

---

## 1. Flash it

1. Unplug the 5V adapter. Plug the Mega into the laptop with USB. (Never both at once.)
2. Arduino IDE → **File → Open** → `firmware/focusfreak/focusfreak.ino`.
3. Library Manager, once: **U8g2**, **RTClib** (Adafruit), **Servo** (Arduino).
4. **Tools → Board → Arduino Mega or Mega 2560**, **Tools → Port → `usbmodem…`**.
5. **Upload**. Then unplug USB and run it on the adapter.

The first boot sets up the EEPROM by itself. Settings, alarms, best scores, the last
routine from the app and 30 days of history survive power cuts.

---

## 2. Controls

| Control | Does |
|---|---|
| Turn the knob | Next / previous page or item |
| Press the knob | Select. On a running block: pause / resume |
| Hold the knob (0.6 s) | Back to home. On a running block: Skip / Stop menu |
| Push button | Open the menu, or go back |
| Top touch pads | Pet the bot: heart, happy face, **the ear wiggles**. Three quick taps and it laughs |
| Front touch pad | Poke: the eyes go wide |

In games the pads and knob are the game controls (each game's screen says how).

---

## 3. What it does on its own (no phone)

- **Home pages** (turn the knob): Face, Clock, Room (temperature, humidity, comfort),
  Desk (light, your distance, how long you have been sitting), Today (verified minutes,
  streak). A **Focus** page is added in front while a block runs.
- **Menu**: Focus timer, **Routines** (Pomodoro 25/5, 52/17, Deep Work 90/20,
  Ultradian 3x90), Music (30 tunes, 4 play modes), Games (Snake, Blocks, Dino Run,
  Flap, Star Raid, Breakout, Paddle, 2048, Reaction), Alarms (4), Room, Settings.
- **Verification**: a tracked block counts as *verified* only while you sit at the desk
  (HC-SR04, 20 to 90 cm), and, when the app is connected, while your phone is locked.
  Breaks are never tracked. Stepping away does not stop the timer; only the verified
  minutes stop, same as the app.
- The face gets sleepy after 5 minutes with nobody around or in a dark room, wakes up
  and looks at you when you sit down, and suggests a stretch after 50 minutes of sitting.

---

## 4. With the app

1. Phone Bluetooth on, then open the app → **More → Connect a bot** (or the Bot tab →
   Connect my bot). The HC-05 shows up as `HC-05` (or `FocusFreak-XXXX` if you renamed
   it: `../app/docs/BOT_PROVISIONING.md`). Tap it. The PIN is `1234`.
2. On connect the app sets the bot's clock and pulls its history.
3. Start a routine or a timer in the app: the bot runs it too, and the app shows
   the bot's live countdown, mood, and presence.
4. The knob drawn in the app's Bot tab turns the real knob. Games and tunes opened
   from the app's Home open on the bot.
5. Walk away with the phone: the bot keeps running the routine by itself (it holds
   the next 16 blocks).

---

## 5. If something is off

| Symptom | Look at |
|---|---|
| Blank screen | OLED wiring (section 3.1 of the wiring guide). Flash `hardware_test` to check |
| Knob moves 2 items per click | `ENC_STEPS_PER_DETENT` in `focusfreak/sensors.cpp`: set 2 |
| Knob goes the wrong way | Swap `PIN_ENC_CLK` / `PIN_ENC_DT` in `focusfreak/pins.h` |
| Ear hits the box | `SERVO_EAR_MIN` / `SERVO_EAR_MAX` in `focusfreak/pins.h` |
| "Sit down to start" never goes away | HC-SR04 is not echoing: Trig on D22, Echo on D24 |
| Clock wrong | Connect the app once: it sets the time |
| App finds no bot | HC-05 LED must blink fast. Pair from the app, not Android settings |

Protocol test without a phone: the firmware also speaks the app protocol on USB.
`python3 app/tools/sim.py app --serial /dev/cu.usbmodemXXXX --baud 115200 --push` runs the
handshake, pushes a routine and polls status.

After changing icons, tunes or routines in the Dart BotOS, run
`python3 app/tools/make_firmware_assets.py` and flash again.
