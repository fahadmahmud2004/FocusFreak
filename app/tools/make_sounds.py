#!/usr/bin/env python3
"""Generates the app's cue tones.

The sounds ship as assets so the app stays fully offline, and they are
generated rather than downloaded so there is a *source* for them: a tone you
can only re-tune by finding the original WAV again is a tone nobody re-tunes.
Stdlib only, like `sim.py`.

    python3 tools/make_sounds.py            # writes focusfreak_app/assets/sounds/

Design rules — the same no-punishment rule the bot's
moods follow:

* Nothing is harsh. A cue that makes you flinch trains you to silence it.
* Start rises, end settles. The shape says which one it is before you have
  thought about it.
* The tick is quiet and short. It marks the last three seconds; it does not
  count you down like a game show.
* The alarm repeats instead of getting louder. Insistence is fine, escalation
  is the punishment ladder wearing a bell.
"""

import math
import os
import struct
import wave

RATE = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "focusfreak_app", "assets", "sounds")


def note(freq, seconds, amp=0.5, attack=0.008, decay=None, harmonic=0.18):
    """One soft sine note with a plucked envelope, as float samples."""
    n = int(RATE * seconds)
    decay = decay if decay is not None else seconds
    out = []
    for i in range(n):
        t = i / RATE
        # Linear attack keeps the onset from clicking; exponential decay is
        # what makes it read as a struck bell rather than a beep.
        env = min(1.0, t / attack) * math.exp(-3.2 * t / decay)
        s = math.sin(2 * math.pi * freq * t)
        s += harmonic * math.sin(4 * math.pi * freq * t)
        out.append(amp * env * s / (1 + harmonic))
    return out


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*tracks):
    """Overlays tracks, longest wins."""
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    return out


def at(offset_s, samples):
    """Places samples at an offset, for overlapping notes."""
    return silence(offset_s) + samples


def write(name, samples):
    path = os.path.join(OUT_DIR, name)
    peak = max(0.0001, max(abs(s) for s in samples))
    # Normalise to -3 dBFS: loud enough across a room, with headroom so no
    # device's resampler clips it.
    gain = 0.707 / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
        for s in samples
    )
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)
    print(f"{name}: {len(frames) / 1024:.0f} KB, {len(samples) / RATE:.2f}s")


def block_start():
    """Two notes rising. Something is beginning."""
    return mix(
        note(659.25, 0.34, amp=0.42),              # E5
        at(0.11, note(987.77, 0.55, amp=0.50)),    # B5
    )


def block_end():
    """Three notes settling. Something is finished — not failed, finished."""
    return mix(
        note(987.77, 0.36, amp=0.44),              # B5
        at(0.14, note(783.99, 0.40, amp=0.44)),    # G5
        at(0.30, note(587.33, 0.95, amp=0.50)),    # D5
    )


def tick():
    """The last three seconds. Quiet, short, unmistakably a tick."""
    return note(1244.51, 0.05, amp=0.30, attack=0.001, decay=0.018,
                harmonic=0.55)


def alarm():
    """The block is over and you may not be looking at the phone.

    Four rising notes, a pause, repeated. The repeat is what carries across a
    room; it never gets louder, and it stops on its own.
    """
    motif = mix(
        note(659.25, 0.22, amp=0.5),
        at(0.16, note(783.99, 0.22, amp=0.5)),
        at(0.32, note(987.77, 0.22, amp=0.5)),
        at(0.48, note(1318.51, 0.75, amp=0.55)),
    )
    out = []
    for _ in range(3):
        out += motif + silence(0.45)
    return out


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write("block_start.wav", block_start())
    write("block_end.wav", block_end())
    write("tick.wav", tick())
    write("alarm.wav", alarm())
