# FocusFreak — Architecture & engineering rules

Offline-first focus and time-management app, and the companion/control layer for
the FocusFreak desk bot (CSE 315 course project, BUET).

Paths below are relative to `app/focusfreak_app/` unless they start with `firmware/` or `app/`.

The app has to be two things at once and both matter:

1. A product someone would use daily **with no hardware at all**.
2. A faithful mirror and controller for the physical bot when one is connected.

## Stack

Flutter 3.35 / Dart 3.9 · Riverpod 2 (manual providers, no codegen) · Drift
(SQLite) · go_router · fl_chart · `pdf`/`printing` · `audioplayers`.
Android native pieces are hand-written Kotlin behind platform channels, not
plugins — see `docs/PROTOCOL.md` §1 for why.

Targets: **Android** is the product, and the Android toolchain is installed and
green. macOS/web are development surfaces only. For quick visual checks use
`flutter run -d web-server --web-port=5599` for visual checks.

The device layer lives behind a `Transport` seam: `LoopbackTransport` (an
in-process `SimulatedDevice`) and `BluetoothTransport` (the hand-written
`BtClassicPlugin.kt`) are interchangeable, so device features are built and
tested with no hardware.

**The Flutter engine outlives the activity.** `MainActivity` caches it and
attaches, rather than owning it, because a stock `FlutterActivity` destroys its
engine in `onDestroy` — which would kill the Dart session engine the moment
someone swiped the app away, while `FocusTrackingService` sat in the shade still
claiming to track the block. Anything needing an `Activity` reads it through
`ActivityHolder` and does nothing when it is null; plugins are constructed once
per engine in `FocusFreakPlugins`, never per activity.

## Non-negotiable

- **No cloud, no accounts, no analytics, no ads.** All data is local. The only
  thing that leaves the phone is Bluetooth traffic to the user's own bot.
- **Works fully offline.** This is why the app does not use `google_fonts` — it
  fetches over the network on first paint. Platform fonts only.
- **Never fake a sensor reading.** If a verification factor has no source, the
  app shows it as *unavailable* and excludes it. It never guesses, and it never
  presents an app-only session as sensor-verified.

  In practice this means a `VerificationSource` **derives** `providedFactors`
  from what it last actually read, rather than declaring a fixed set up front.
  The Kotlin plugins emit a *sparse* map and absence is how "no source" travels;
  every failure path — no plugin, no grant, no sensor, not Android — resolves to
  an empty map. Declaring a factor and forgetting to set it is not a small bug
  here: it silently verifies every session. It happened once already, and
  `test/phone_verification_source_test.dart` exists to stop it happening twice.
- **The device is optional, always.** Nothing in the app may require a bot to be
  connected.
- **No punishment or shame mechanics.** The bot's mood is the feedback channel.
  It is a product decision, not a style preference: disappointing a character
  works where a buzzer only trains you to mute it.

## Firmware parity

`docs/PROTOCOL.md` is the contract. `lib/device/protocol.dart` and the firmware's
`proto.cpp` are both written from it; neither changes a byte layout alone.

`lib/core/ff_constants.dart` mirrors the firmware constants (grace periods,
presence window, struct limits). `lib/design/ff_colors.dart` derives the six
category colours from the firmware's RGB565 words rather than restating them as
hex.

`test/firmware_parity_test.dart` asserts all of this. **If it fails, the app and
the device disagree about something a user can see. Fix the mismatch — do not
relax the test.**

## Architecture

```
lib/
  app/        router, shell, page scaffold
  core/       constants, formatting, date maths
  design/     colours, type, themes, components   <- no feature imports these backwards
  data/       drift schema, DAOs, repositories
  domain/     models + pure-Dart engines (session, verification, mood, streak, insight)
  botos/      BotOS: the bot's firmware in pure Dart (screens, face, games,
              music, U8g2 fonts). The virtual bot runs it; the Arduino port
              follows it
  device/     protocol codec + transports + device repository
  platform/   thin Dart side of the Kotlin channels
  features/   one folder per screen area
```

The engines in `domain/engine/` are pure Dart with no Flutter imports. They are
the only place session or verification logic may live, and they are unit-tested
directly.

**A restore merges; it never deletes.** `DataImport` writes over rows that
match by id and leaves everything else alone. This database is the user's only
copy — there is no cloud to re-download from — so one mis-tapped file must not
be able to destroy a year. Milestones follow the same instinct: derived on
every read, and a recount can never revoke one.

**Sound is four cues and no consequences.** `SessionController` emits a
`SessionCue`; `SoundCues` plays a tone, and `AlarmScheduler` keeps one system
alarm in step with the running block for when the app is not alive. There is
deliberately **no sound for a violation or a broken block** — that is the
buzzer punishment ladder rebuilt.
`audioplayers` lives behind `SoundOutput` in `platform/sound_player.dart` and
is imported nowhere else; tests use `SilentSoundOutput`. The tones are
generated into `assets/sounds/` by `../tools/make_sounds.py` — edit that script,
not the WAVs.

**One `BotState`, one `BotView`, two producers.** `VirtualBotEngine` runs the
device's state machine locally; `DeviceMirror` decodes `0xB0 STATUS` frames.
Every consumer watches `botStateProvider`, which is the mirror when a bot is
attached and the virtual engine otherwise, so connecting hardware swaps the
producer and changes nothing else. `FaceAnimator` holds the parts neither
source supplies — blink, gaze drift, the 8-frame mood blend — so both faces are
alive in the same way.

**BotOS is the bot.** `lib/botos/` is the firmware written once in Dart: a
128 x 64 one-bit framebuffer with U8g2's drawing calls and U8g2's own fonts,
the face, the home pages, the menu, music and games. `BotOsHost` runs it at
25 fps for the virtual bot and draws it with `OledDisplay`; the Arduino
firmware is ported from it screen by screen, so the phone and the desk show
the same pixels. Keep it free of Flutter imports.

## Writing for the screen

Every string a user can read is **product copy, not an explanation of how the
app works**. The reasoning behind a decision belongs in the code comment beside
it; the screen gets the short version, in the user's terms.

| Written for the developer | Written for the user |
|---|---|
| "The default. Matches the logo." | "Easy on the eyes at night." |
| "Read from the device, not assumed. Anything it does not have is left out of verification rather than counted against you." | "A sensor your bot does not have is never counted against you." |
| "A longer routine is refused rather than cut short." | "Longer routines stay in the app." |
| "This bot speaks protocol 2 and the app speaks 1." | "This bot runs older software than the app expects." |

Two habits give it away: naming internals the user has never heard of
(protocol numbers, resolutions, "the loopback"), and defending a decision they
never questioned ("rather than…", "instead of…").

## Conventions

- Spacing, radius and motion come from `design/ff_tokens.dart`. A hard-coded
  number in a widget is a bug.
- Colours come from `context.ff` (the `FfPalette` theme extension), never from
  `FfColors` directly in a widget.
- Every list gets a real `FfEmptyState`.
- Countdowns use `FfType.countdown*`, which carry tabular figures. A timer whose
  digits change width jitters.

## Commands

```bash
flutter analyze                                  # must be clean
flutter test                                     # must be green
flutter run -d web-server --web-port=5599        # visual check — RESTART it
                                                 # after edits; it never
                                                 # recompiles on its own
flutter build apk --debug                        # Android toolchain is installed
dart run build_runner build --delete-conflicting-outputs   # after drift changes
python3 ../tools/sim.py selftest                 # protocol vectors, no Flutter
python3 ../tools/make_sounds.py                  # regenerate assets/sounds/
python3 ../tools/make_fonts.py                   # U8g2 fonts -> lib/botos/fonts.g.dart
python3 ../tools/make_routines.py                # FW routines -> template_catalog.dart
```
