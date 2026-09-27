# Engineering notes

Bugs that cost real time, the lessons they left, and the rules the test suite enforces. Each bug below has a regression test.

## Bugs found and fixed — do not reintroduce

| Bug | Lesson |
|---|---|
| `Row` + `CrossAxisAlignment.stretch` in an unbounded vertical context collapsed every card to zero height | **Silent.** No error, just blank space |
| `BoxDecoration` rejects a `borderRadius` with non-uniform border widths | The obvious first fix for the above — it does not work |
| `ColoredBox` has no intrinsic height, so shape-bar segments collapsed under a Row's default centre alignment | The bar measured correctly and painted nothing. **A size assertion was not enough** — assert on the segments |
| `pw.Column` cannot split across pages in a `MultiPage` → `TooManyPagesException` | Spread long tables as top-level widgets |
| 90 daily bars produced a 1 MB unreadable PDF chart | Ranges past 35 days bucket into weeks |
| PDF em-dashes and middle dots rendered as hollow boxes | Built-in Helvetica lacks the glyphs |
| Mood interpolation was dead code — `BotState.eyes` derived from the mood enum, so the 8-frame blend never showed | Now flows through `eyeShape`, with a test |
| Night Owl template left a 60-minute hole at midnight | A day summing to 1440 can still be wrong — test *contiguity*, not just the total |
| On-colour text used a fixed luminance threshold; failed at 2.1:1 on the mint Active Work colour | Pick whichever of black/white actually wins the contrast comparison |
| Deload logic had streak-freeze behaviour leaking in | A day off is exactly the rest that makes the suggestion unnecessary |
| Replies matched to requests by command byte drifted by one | The protocol has no sequence numbers. CONTROL and COMMIT also answer with `0xB0 STATUS`, so an unclaimed one shifted every later match and the UI showed the *previous* state. **Every frame the device sends must be claimed by exactly one waiter**, and the poll is silenced during a routine push |
| **A manual pause undid itself one tick later** | The engine could not tell a user-chosen pause from a verification pause, so the next tick saw "paused, and verification holds" and resumed. The Pause button appeared dead. `_pausedByUser` now separates them, and `docs/PROTOCOL.md` §9 carries the same rule for the firmware |
| Hiding a template was a one-way door | `archive()` had no caller passing `archived: false`. Anything one tap can remove, one tap must be able to restore |
| **The phone claimed LOCK was holding with no sensor behind it** | `phoneVerificationSourceProvider` declared `screenLock` and nothing ever `set` it, and `ManualVerificationSource` defaults an unset factor to *holding*. Every bot-less session verified itself. **A source must derive what it provides from what it actually read** |
| `_closeLink()` nulled `_simulated` on a *first* connect | The old `_connect` called `disconnect()`, which returned early when there was no link. Splitting teardown lost that early return and the virtual bot's own controls had nothing to drive. An extracted helper has to keep the guard the original relied on |
| `ref` used in a `ConsumerState.dispose()` | Riverpod throws "Cannot use ref after the widget was disposed". Capture the notifier in `initState`; the scan would otherwise never be stopped |
| A section's switches never moved | It used `ref.read`, so it never rebuilt. Flipping a switch changed the device and left the switch behind |
| Three buttons in a `Row` overflowed a 360 dp phone | An overflow stripe across the controls of a running focus session. `Wrap`, not `Row` |
| A selected `ChoiceChip` was Material's default green with an unreadable label | The theme styled the *unselected* chip only. A component half-themed looks like a bug in the one state nobody screenshots. `chipTheme` now carries `selectedColor` and `secondaryLabelStyle` |
| A NACK failed every outstanding request | `0x03 UNKNOWN_CMD` is informational. Failing an unrelated request over it turns forward compatibility into an error |

## Testing traps

Widget tests **hang rather than fail** under `testWidgets`' fake-async zone
whenever they wait on something the fake clock will not
advance. Feed widgets fixed data; cover database behaviour at the repository
level. `test/routine_editor_test.dart` shows the basic pattern and
`test/device_screen_test.dart` shows the three device-specific traps, each of
which cost a hung run to find:

| Symptom | Cause | Fix |
|---|---|---|
| The test never finishes | An awaited `Future.delayed` (the transport's latency) whose timer only fires while the test pumps | Do the connect inside `tester.runAsync` |
| `pumpAndSettle` never returns | A live link holds two periodic timers — the status poll and the parser resync | Pump single frames |
| A section renders as nothing | A `MethodChannel` reply needs a real event loop, so `bluetoothAvailableProvider` never resolves | Override the provider with a fixed value |
| "A Timer is still pending" | The test left the link open | Disconnect before the test ends |
| "A SemanticsHandle was active at the end of the test" | `addTearDown(handle.dispose)` runs *after* the assertion | Call `dispose()` inline at the end of the body |

---

## Tone rules, enforced by tests

`test/insight_engine_test.dart` asserts a banned-word list — `only`, `failed`,
`poor`, `should`, `must`, `wasted`, `lazy`, `great job`, `amazing`, `crushed` —
and no exclamation marks.

- **Never shame.** A person who feels judged by their tools stops opening them,
  and an unopened app has an effect size of zero.
- **Never flatter.** No invented streaks, no rounding up, no praise for a bad
  week.
- **Never claim what the data cannot support.** Below a minimum sample the
  engine says nothing rather than reading noise as a pattern.
- **No punishment mechanics.** The bot's mood is the feedback channel.
  It is a product decision, not a style preference.

On-screen text is product copy, not an explanation of how the app works — see "Writing for the screen" in [`ARCHITECTURE.md`](ARCHITECTURE.md).
