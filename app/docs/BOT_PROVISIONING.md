# Bot provisioning

What every FocusFreak unit needs before it leaves the bench, and why the app
depends on it.

This is the other half of the connect flow. The app scans, shows bots, and pairs
with one tap — no trip to Android settings, no PIN typed. That only works if
every unit is named and configured the same way, which is what this sheet is
for.

The customer's whole experience is meant to be: **unbox → switch on → scan the
QR on the bot's screen → install → tap the bot in the list → done.** Every step
below exists to protect one part of that.

---

## 1. What the app expects

| Setting | Value | Why the app needs it |
|---|---|---|
| Name | `FocusFreak-XXXX` | The scan filters on it. A café scan turns up thirty earbuds, and every one is a way to tap the wrong thing. |
| PIN | `1234` | The app answers the pairing request itself, so the user never sees a code. One PIN across all units is what makes that possible. |
| Baud | `9600` | `FfFirmware.baudRate`. A full 16-block routine push is ~0.8 s at this speed. |
| Role | Slave (`0`) | The phone opens the connection. |
| Connect mode | Fixed address (`0`) | The module answers, it does not go looking. |

`XXXX` is the **last four hex digits of the module's own MAC**. Not a counter:
two people in the same room with sequentially numbered bots would both see
`FocusFreak-0001` and `FocusFreak-0002` and have no way to tell which is theirs.
The MAC suffix is unique, already printed by `AT+ADDR`, and needs no
bookkeeping.

> **The PIN is not a secret and is not treated as one.** Bluetooth Classic
> pairing on an HC-05 is not a security boundary, and the thing on the other end
> is a desk toy that reports whether a chair is occupied. Asking every customer
> to type a code that protects nothing would be friction with no payoff.

---

## 2. Entering AT mode

The HC-05 only accepts AT commands while its KEY/EN pin is high **at power-up**.

1. Disconnect the module's VCC.
2. Hold the small button on the module down, or wire KEY to 3.3 V.
3. Reconnect VCC. The onboard LED should now blink **slowly, about once every
   two seconds**. A fast blink means it is in normal mode and no command below
   will be accepted.
4. Open a serial monitor at **38400 baud, both NL and CR** line endings. AT mode
   is always 38400 regardless of what the data rate is set to — this catches
   everyone once.

Verify before changing anything:

```
AT
```

It must answer `OK`. If it does not, the blink rate or the line endings are
wrong; nothing below will work until this does.

---

## 3. The sequence

Read the address first, because the name depends on it:

```
AT+ADDR?
```

It answers something like `+ADDR:98d3:31:fb1234`. Take the **last four
characters** — `1234` here — and use them below.

```
AT+NAME=FocusFreak-1234
AT+PSWD="1234"
AT+UART=9600,0,0
AT+ROLE=0
AT+CMODE=0
```

Two notes that cost time if missed:

* **`AT+PSWD` quoting differs by firmware version.** Newer HC-05 firmware wants
  `AT+PSWD="1234"`; older wants `AT+PSWD=1234` and answers `ERROR:(0)` to the
  quoted form. Try the quoted form first, fall back to the bare one.
* **`AT+UART=9600,0,0` is the data rate, not the AT rate.** After this the
  module still talks AT at 38400. Do not "fix" it.

---

## 4. Verifying a unit

Power-cycle out of AT mode first — release the button, replug VCC, confirm the
LED is blinking fast.

Then, from a phone with the app installed:

1. Open **More → Connect a bot**. The bot appears within a few seconds as
   `FocusFreak-XXXX`.
2. Tap it. It should pair and connect **with no PIN prompt at any point.** A
   system PIN dialog appearing means `AT+PSWD` did not take — go back to §3.
3. The connection card should show firmware and protocol versions, and the
   capability chips should match what this unit actually has fitted.
4. Cut power to the bot. The status badges must go unavailable within about
   fifteen seconds — not freeze on their last values.
5. Power it back on. The app should reconnect on its own, without being touched.

Steps 4 and 5 are the ones worth not skipping: they are what separates a bot
that is trusted from one that quietly keeps vouching for an empty chair.

---

## 5. The QR code

The QR on the bot's screen is a **plain Play Store URL** —
`https://play.google.com/store/apps/details?id=com.freakingwaves.focusfreak_app`
— and any camera app resolves it. There is deliberately **no app-side code**
behind it: no deep link to handle, no pairing token encoded in it, nothing to
keep in sync between firmware and app.

That is a decision, not an omission. A QR carrying a pairing payload would mean
a bot whose screen is broken cannot be set up, and a scan flow that has to be
maintained in both firmware and app forever. The scan finds the bot by name;
the QR only has to get the app installed.

Render it from the firmware once at boot into a corner of the idle screen, or
print it on the underside of the case. Both work, and the case survives a dead
display.
