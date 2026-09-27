# FocusFreak App — Specification

Companion to `PROTOCOL.md`. That file describes the wire; this one describes the
product.

---

## 1. What the app is

> A desk-companion app that plans your day in blocks, times them, and reports
> honestly on how much of that time you actually focused — with or without the
> hardware.

Two promises, and the second is what makes it different:

1. **Standalone.** Everything works with no bot, no account and no network.
2. **Honest.** The headline number is never "minutes claimed". It is verified
   against claimed, and the app is explicit about which verification channels
   were available for each session.

### The metric

**Verified Focus Minutes (VFM)** — minutes during a tracked block where every
*available* verification factor held. Claimed minutes are simply elapsed
minutes. The gap between them is the product.

A session records **which factors were available**, so a report never compares
apples to oranges:

| Provenance | Factors |
|---|---|
| `sensorVerified` | presence + dock + screen-lock, from the bot |
| `appVerified` | screen-lock (+ phone-still, + app-usage) from the phone alone |
| `untracked` | the block ran with tracking off — a plain timer |

The app never presents `appVerified` as `sensorVerified`. That distinction is
the entire argument for the hardware existing, so blurring it would be arguing
against ourselves.

---

## 2. Information architecture

Five tabs.

| Tab | Holds |
|---|---|
| **Today** | Current/next block, live countdown, VFM vs claimed, streak, day timeline, top tasks, one insight |
| **Plan** | Routines (templates + custom), the routine editor, tasks |
| **Bot** | The virtual device — all six screen modes, the face, the ring. `LIVE` when hardware is connected |
| **Stats** | Day/week/month/year/all-time, charts, session log, violation log, PDF reports |
| **More** | Rules library, device pairing, settings, backup, about |

The bot sits in the middle of the bar deliberately. It is the thing that makes
this not a to-do list.

---

## 3. Routines and blocks

A **Routine** is an ordered list of **Blocks**. A Block mirrors the firmware
struct exactly (`PROTOCOL.md` §5) so any routine is pushable:

| Field | Limit | Note |
|---|---|---|
| `name` | 16 chars | enforced in the editor, never truncated on push |
| `desc` | 24 chars | same |
| `durationMin` | uint16 | |
| `category` | 0..5 | the six shared categories |
| `trackEnabled` | bool | **per block** |
| `startMin` | minutes since midnight, or sequential | |

**Per-block tracking is the most important UX decision in the product.**
Always-on tracking makes the device a tyrant; opt-in per block makes it a tool.
Default: on for Deep Work, off for everything else.

### Built-in templates

Read-only, with a "Duplicate to edit" action.

* **Standard** — wake 05:00, sleep 23:00
* **Early Bird** — wake 03:00, same structure shifted
* **Night Owl** — wake 10:00, Active Work first
* **Pomodoro 25/5**, **52/17**, **Deep Work 90/20**
* **Exam Cram**, **Deload day**

Routines may exceed 16 blocks in the app. Only 16 push to the device, and the
editor says so plainly rather than silently dropping the rest.

### Tasks

Separate from blocks, optionally linked to one. Projects, tags, priority, due
date, subtasks, notes, recurrence, estimated pomodoros, and "focus this now"
which starts a timer bound to the task.

---

## 4. Session lifecycle

The app runs the same state machine as the firmware (the firmware):

```
IDLE ──start / scheduled──> ARMED
ARMED ──conditions met──> RUNNING          ARMED ──15 s──> IDLE
RUNNING ──unverified > 30 s──> PAUSED      [timer frozen]
PAUSED ──restored──> RUNNING
PAUSED ──> 5 min──> BROKEN                 [streak reset, logged with reason]
RUNNING ──duration elapsed──> COMPLETE ──> next block
any ──cancel──> IDLE                       [logged as abandoned]
```

Grace periods are firmware constants, mirrored in `lib/core/ff_constants.dart`
and asserted in `test/firmware_parity_test.dart`.

### Verification inputs

| Factor | With bot | App-only | If neither |
|---|---|---|---|
| Present at desk | HC-SR04, 20–90 cm | — | omitted |
| Phone docked | TCRT5000 IR | accelerometer: still and face-down | omitted |
| Screen locked | app heartbeat | `ACTION_SCREEN_ON/OFF` receiver | omitted |
| Distraction | — | `UsageStatsManager` | omitted |

An omitted factor is **excluded from the verdict and shown as unavailable**. It
is never assumed true and never assumed false.

**Graceful degradation:** if the bot is connected but the app is not reachable,
the device falls back to 2-factor. If the bot is absent, the app falls back to
app-only and labels the session accordingly.

---

## 5. The virtual bot

A 320×240 logical canvas — the device's real resolution — scaled to fit, with
all six modes from the frozen spec:

| Mode | Trigger (virtual) |
|---|---|
| D1 Ambient | idle |
| D2 Attention | phone proximity sensor |
| D3 Task | a tracked block is running |
| D4 Pet | tap/stroke the head |
| D5 Pair | pairing flow |
| D6 Dim | 5 min idle |

**Procedural face, never bitmaps.** Eyes are parameterised exactly as the
firmware `Eye` struct — `cx, cy, w, h, radius, lidTop, lidBot, slant` — so
values tuned in the app transfer straight to the firmware. Five moods
(`CALM, SEARCHING, SAD, HAPPY, SLEEPY`) with 8-frame interpolation, autoblink
every 3–6 s, cardinal gaze, idle drift. Animated at 25 fps to match the device
rather than 60.

**The mood is the feedback mechanism.** No buzzer punishment, no shame copy, no
streak-loss guilt trip. A device that punishes ends up in a drawer by week three;
disappointing a character does not.

---

## 6. Stats, insights, reports

Ranges: day / week / month / year / all-time.

Charts: verified-vs-claimed bars, category breakdown, year heatmap, hour-of-day
focus histogram, streak history, session list, violation log with reasons and
timestamps.

**Insights are factual and never shaming.** *"You verified 68% of your claimed
study time this week."* *"Your best focus happens 06:00–09:00."* *"Six
high-intensity days in a row — the Deload template is one tap away."*

When bot data exists: an environment correlation panel (light / temperature /
humidity against verified minutes).

**Reports:** PDF for daily, weekly, monthly, custom range and all-time — logo
header, summary tiles, charts drawn into the PDF, block table, violation log,
the honest verified/claimed split. Plus CSV/JSON export and a full SQLite
backup/restore, because there is no cloud and the user must own an escape hatch.

---

## 7. The rules library

The 11 research-backed rules, each with its citation, the app feature that
implements it, and a badge where the hardware can actually verify it.

Three of the eleven are sensor-verifiable, and that is the headline:

| # | Rule | Verified by |
|---|---|---|
| 7 | Morning sunlight within 30 min of waking | ambient light sensor reads real lux |
| 8 | 20-20-20 | distance sensor confirms you looked away |
| 9 | Deep work, phone away | dock + IR + screen-lock heartbeat |

The other eight are timed or structural. The app says which is which.

---

## 8. Constraints, stated plainly

These belong in the report as much as in the code.

* **iOS cannot talk to HC-05.** Bluetooth Classic needs MFi. The app can run on
  iOS standalone; the bot connection is Android-only until an HM-10 (BLE) swap.
* **A web app can never do background screen tracking.** Web Bluetooth has no
  background mode on any platform and does not exist on iOS. A future web build
  is view/edit/stats only; the native Android app stays mandatory.
* **9600 baud, ≤64 B payloads.** Fine for control, unfit for bulk transfer.
* **The device holds 30 days of logs.** The phone is the archive; the app pulls
  on every connect.
* **Phone sensors are weaker than the bot's.** Proximity is a ~5 cm binary, not
  a distance. There is no true desk-presence detection without the hardware.
* **Android OEM service killers** (Xiaomi, Oppo, Vivo, Realme) are the biggest
  reliability risk to the heartbeat, and are handled with an explicit onboarding
  step rather than hope.

---

## 9. Privacy

No accounts. No cloud. No analytics. No ads. No camera, ever — the whole
sensing approach is privacy-preserving by construction, and that is a selling
point, not a limitation.

`UsageStatsManager` access is opt-in, explained before it is requested, and the
app works fully without it.
