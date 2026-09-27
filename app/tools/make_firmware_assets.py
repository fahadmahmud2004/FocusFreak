#!/usr/bin/env python3
"""Exports BotOS assets from the Dart sources to the Arduino firmware.

    python3 tools/make_firmware_assets.py

The Dart BotOS (`focusfreak_app/lib/botos/`) is the reference the firmware is
ported from. Icons, sprites, melodies, alarm tones and the on-device routine
templates are *data*, so they are not re-typed in C++: this script reads them
out of the Dart files and writes `firmware/focusfreak/assets.h` and
`assets.cpp`. Re-run it after changing any of them in Dart; never edit the
generated C++.

Stdlib only.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "..", "focusfreak_app", "lib")
BOTOS = os.path.join(LIB, "botos")
OUT_DIR = os.path.join(HERE, "..", "..", "firmware", "focusfreak")

# The routines the bot can start on its own, in menu order. Keys in
# `lib/domain/model/template_catalog.dart`. Must match `BotRoutines.keys` in
# `lib/botos/routines.dart`.
ROUTINE_KEYS = ["pomodoro", "fiftyTwo", "deepWork", "ultradian"]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def dart_strings(src):
    """Every single-quoted Dart string literal in src, unescaped, in order."""
    out = []
    for m in re.finditer(r"'((?:[^'\\]|\\.)*)'", src):
        out.append(re.sub(r"\\(.)", r"\1", m.group(1)))
    return out


# --- bitmaps ------------------------------------------------------------------

def bitmaps(src):
    """`static const List<String> name = <String>[ '..#', ... ];` blocks."""
    found = {}
    for m in re.finditer(
        r"static const List<String> (_?\w+) = <String>\[(.*?)\];", src, re.S
    ):
        rows = dart_strings(m.group(2))
        if rows and all(set(r) <= set("#.") for r in rows):
            found[m.group(1).lstrip("_")] = rows
    return found


def c_bitmap(name, rows):
    w = max(len(r) for r in rows)
    h = len(rows)
    per_row = (w + 7) // 8
    data = [w, h]
    for r in rows:
        r = r.ljust(w, ".")
        for b in range(per_row):
            byte = 0
            for i in range(8):
                x = b * 8 + i
                if x < w and r[x] == "#":
                    byte |= 1 << i
            data.append(byte)
    body = ", ".join(f"0x{v:02X}" for v in data)
    return f"const uint8_t {name}[] PROGMEM = {{{body}}};"


# --- melodies -----------------------------------------------------------------

def melodies(block):
    """`Melody('Title', 'rtttl' 'more', by: 'Who')` entries, in order."""
    out = []
    for m in re.finditer(r"Melody\((.*?)\)(?=\s*[,\]])", block, re.S):
        body = m.group(1)
        by = ""
        bm = re.search(r"by:\s*((?:'(?:[^'\\]|\\.)*'\s*)+)", body)
        if bm:
            by = "".join(dart_strings(bm.group(1)))
            body = body[: bm.start()]
        parts = re.split(r",\s*(?='|\s*$)", body.strip().rstrip(","), maxsplit=1)
        title = dart_strings(parts[0])[0]
        rtttl = "".join(dart_strings(parts[1]))
        out.append((title, by, rtttl))
    return out


def list_block(src, anchor):
    """The text between `anchor` and the matching `];`."""
    i = src.index(anchor)
    j = src.index("];", i)
    return src[i:j]


def c_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- routines -----------------------------------------------------------------

def routine(catalog, key):
    m = re.search(r"RoutineTemplate\(\s*key: '" + re.escape(key) + r"',(.*?)\n  \),", catalog, re.S)
    if not m:
        sys.exit(f"routine {key} not found")
    body = m.group(1)
    name = dart_strings(re.search(r"name: ((?:'(?:[^'\\]|\\.)*'\s*)+)", body).group(1))[0]
    blocks = []
    for bm in re.finditer(r"TemplateBlock\((.*?)\)", body, re.S):
        b = bm.group(1)

        def s(field):
            mm = re.search(field + r": ((?:'(?:[^'\\]|\\.)*'\s*)+)", b)
            return "".join(dart_strings(mm.group(1))) if mm else ""

        def n(field, default=0):
            mm = re.search(field + r": (\d+)", b)
            return int(mm.group(1)) if mm else default

        track = re.search(r"track: true", b) is not None
        if re.search(r"startMin: \d", b):
            sys.exit(f"{key}: clock-anchored blocks are not supported on the bot")
        blocks.append((s("name"), s("description"), n("durationMin"), n("category"), track))
    if len(blocks) > 16:
        sys.exit(f"{key} has {len(blocks)} blocks, the bot holds 16")
    return name, blocks


def wire_block(name, desc, minutes, category, track):
    """The 48-byte Block struct from docs/PROTOCOL.md section 5."""
    nb = name.encode("ascii")
    db = desc.encode("ascii")
    assert len(nb) <= 16 and len(db) <= 24, (name, desc)
    out = bytearray(48)
    out[0:len(nb)] = nb
    out[16:16 + len(db)] = db
    out[40] = minutes & 0xFF
    out[41] = minutes >> 8
    out[42] = category
    out[43] = 1 if track else 0
    out[44] = 0xFF
    out[45] = 0xFF
    return out


def main():
    icons = bitmaps(read(os.path.join(BOTOS, "icons.dart")))
    sprites = {}
    for f in ("games.dart", "arcade.dart"):
        sprites.update(bitmaps(read(os.path.join(BOTOS, f))))

    music = read(os.path.join(BOTOS, "music.dart"))
    tunes = melodies(list_block(music, "static const List<Melody> all"))
    tones = melodies(list_block(music, "class AlarmTones"))
    start = melodies(re.search(r"static const Melody start = (Melody\(.*?\));", music, re.S).group(1) + ",")
    done = melodies(re.search(r"static const Melody done = (Melody\(.*?\));", music, re.S).group(1) + ",")

    catalog = read(os.path.join(LIB, "domain", "model", "template_catalog.dart"))
    routines = [routine(catalog, k) for k in ROUTINE_KEYS]

    h = [
        "// Generated by app/tools/make_firmware_assets.py from the Dart BotOS.",
        "// Do not edit. Re-run the script after changing the Dart sources.",
        "#pragma once",
        "#include <Arduino.h>",
        "",
        "// Bitmaps: [w, h, rows...], each row (w+7)/8 bytes, bit 0 = leftmost pixel.",
    ]
    c = [
        "// Generated by app/tools/make_firmware_assets.py from the Dart BotOS.",
        "// Do not edit. Re-run the script after changing the Dart sources.",
        '#include "assets.h"',
        "",
    ]
    for name, rows in icons.items():
        h.append(f"extern const uint8_t ICO_{name}[] PROGMEM;")
        c.append(c_bitmap(f"ICO_{name}", rows))
    for name, rows in sprites.items():
        h.append(f"extern const uint8_t SPR_{name}[] PROGMEM;")
        c.append(c_bitmap(f"SPR_{name}", rows))

    h += [
        "",
        "struct MelodyDef {",
        "  const char *title;  // PROGMEM",
        "  const char *by;     // PROGMEM",
        "  const char *rtttl;  // PROGMEM",
        "};",
        "",
        f"#define MELODY_COUNT {len(tunes)}",
        f"#define ALARM_TONE_COUNT {len(tones)}",
        "extern const MelodyDef MELODIES[MELODY_COUNT] PROGMEM;",
        "extern const MelodyDef ALARM_TONES[ALARM_TONE_COUNT] PROGMEM;",
        "extern const MelodyDef MELODY_START PROGMEM;",
        "extern const MelodyDef MELODY_DONE PROGMEM;",
    ]

    def emit_melodies(prefix, items):
        refs = []
        for i, (title, by, rtttl) in enumerate(items):
            c.append(f"static const char {prefix}_T{i}[] PROGMEM = {c_str(title)};")
            c.append(f"static const char {prefix}_B{i}[] PROGMEM = {c_str(by)};")
            c.append(f"static const char {prefix}_R{i}[] PROGMEM = {c_str(rtttl)};")
            refs.append(f"  {{{prefix}_T{i}, {prefix}_B{i}, {prefix}_R{i}}},")
        return refs

    c.append("")
    refs = emit_melodies("MEL", tunes)
    c.append("const MelodyDef MELODIES[MELODY_COUNT] PROGMEM = {")
    c += refs
    c.append("};")
    refs = emit_melodies("TONE", tones)
    c.append("const MelodyDef ALARM_TONES[ALARM_TONE_COUNT] PROGMEM = {")
    c += refs
    c.append("};")
    for label, items in (("START", start), ("DONE", done)):
        title, by, rtttl = items[0]
        c.append(f"static const char CUE_{label}_T[] PROGMEM = {c_str(title)};")
        c.append(f"static const char CUE_{label}_B[] PROGMEM = {c_str(by)};")
        c.append(f"static const char CUE_{label}_R[] PROGMEM = {c_str(rtttl)};")
        c.append(f"const MelodyDef MELODY_{label} PROGMEM = {{CUE_{label}_T, CUE_{label}_B, CUE_{label}_R}};")

    h += [
        "",
        "// Routines the bot can start with no phone. Blocks are the 48-byte wire",
        "// struct from docs/PROTOCOL.md section 5, so ROUTINE_GET streams them as is.",
        "struct RoutineDef {",
        "  const char *name;     // PROGMEM",
        "  uint8_t count;",
        "  const uint8_t *blocks; // PROGMEM, count * 48 bytes",
        "};",
        f"#define ROUTINE_TEMPLATE_COUNT {len(routines)}",
        "extern const RoutineDef ROUTINE_TEMPLATES[ROUTINE_TEMPLATE_COUNT] PROGMEM;",
    ]
    c.append("")
    refs = []
    for i, (name, blocks) in enumerate(routines):
        data = bytearray()
        for b in blocks:
            data += wire_block(*b)
        body = ", ".join(f"0x{v:02X}" for v in data)
        c.append(f"static const char RT_N{i}[] PROGMEM = {c_str(name)};")
        c.append(f"static const uint8_t RT_B{i}[] PROGMEM = {{{body}}};")
        refs.append(f"  {{RT_N{i}, {len(blocks)}, RT_B{i}}},")
    c.append("const RoutineDef ROUTINE_TEMPLATES[ROUTINE_TEMPLATE_COUNT] PROGMEM = {")
    c += refs
    c.append("};")

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "assets.h"), "w") as f:
        f.write("\n".join(h) + "\n")
    with open(os.path.join(OUT_DIR, "assets.cpp"), "w") as f:
        f.write("\n".join(c) + "\n")
    print(f"{len(icons)} icons, {len(sprites)} sprites, {len(tunes)} tunes, "
          f"{len(tones)} alarm tones, {len(routines)} routines "
          f"({', '.join(r[0] for r in routines)})")


if __name__ == "__main__":
    main()
