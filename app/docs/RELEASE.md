# Releasing to Play

What still has to happen before FocusFreak can go on the Play Store, and what
only you can do.

**Read this before uploading anything.** Two of the steps below are
irreversible — the applicationId and the upload key — and getting either wrong
means shipping a second app rather than fixing the first.

---

## 1. The upload key — you have to make this, not me

Play refuses debug-signed uploads. The release build currently falls back to
debug signing so it still runs on a phone, which is fine for testing and
useless for uploading.

Creating the key sets a password, so it is yours to run and yours to keep:

```bash
keytool -genkey -v -keystore ~/focusfreak-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `app/focusfreak_app/android/key.properties`:

```
storePassword=<the password you just chose>
keyPassword=<the same one, unless you chose two>
keyAlias=upload
storeFile=/path/to/focusfreak-upload.jks
```

It is already gitignored (`android/.gitignore` lines 12–14) and nothing prints
it. `build.gradle.kts` picks it up automatically and switches to real signing.

> **Back the `.jks` file up somewhere that is not this laptop.** Lose it and
> you cannot update the app ever again — not "with difficulty", at all. Play
> App Signing enrolment softens this, but only if you enrol at first upload.
> Do that.

---

## 2. Things that are locked the moment you upload

| Thing | Value | Why it matters |
|---|---|---|
| applicationId | `com.freakingwaves.focusfreak_app` | **Permanent.** Cannot be changed later without losing every install and review. The `_app` suffix is slightly awkward for a product you intend to sell — if it bothers you, change it *now*, in `build.gradle.kts` and `namespace`. After the first upload it is forever. |
| Upload key | `~/focusfreak-upload.jks` | See above. |
| versionCode | `1`, from `pubspec.yaml` `version: 1.0.0+1` | Must increase on every upload. Bump the `+1`. |

---

## 3. Permission declarations Play will ask about

The app requests four permissions that trigger a review form. Answering these
badly is the most likely reason a first submission bounces.

| Permission | What to say |
|---|---|
| `PACKAGE_USAGE_STATS` | Used only to read *which* app is in the foreground during a focus block the user started, to mark the block unverified. Opt-in, off by default, never leaves the device. |
| `USE_EXACT_ALARM` | **The risky one.** Google restricts it to apps whose core function is an alarm or calendar. FocusFreak's alarm ends a focus block, which is arguably that and arguably not. If it is refused, drop to `SCHEDULE_EXACT_ALARM` (already declared) and accept that the alarm may fire late on a dozing phone. Do not fight it — a rejected submission costs days. |
| `FOREGROUND_SERVICE_DATA_SYNC` | Keeps verification reading while the screen is off. Must match the declared `foregroundServiceType`. |
| `ACCESS_FINE_LOCATION` | `maxSdkVersion="30"` only, because pre-31 Android counted a Bluetooth scan as location. The app derives no location and `BLUETOOTH_SCAN` carries `neverForLocation`. Say exactly that. |

Also required before the store listing goes live:

- **A privacy policy URL.** Non-negotiable, even though the honest policy is
  one paragraph: everything is on the device, nothing is collected, nothing is
  transmitted except Bluetooth traffic to the user's own bot.
- **The Data safety form.** Answer "no data collected". It is true, and it is
  the app's main selling point against Forest and Opal.

---

## 4. Build commands

```bash
flutter build appbundle --release
```

The `.aab` lands in `build/app/outputs/bundle/release/`. That is what Play
wants — not an APK.

For sideloading onto your own phone to run the §7 on-phone checklist:

```bash
flutter build apk --release
```

---

## 5. What is deliberately not enabled

**Code shrinking is off** (`isMinifyEnabled = false`). R8 would strip the
Kotlin plugin classes, because nothing in Java ever calls them — they are only
reached from Dart across a MethodChannel. The app would lose Bluetooth and
every phone-side verification factor **in release builds only**, which is the
worst possible place to find out.

Turning it on later means writing keep rules for
`com.freakingwaves.focusfreak_app.*` and re-running the whole §7 checklist
against a release build. Worth doing eventually for the download size. Not
worth doing the week before a demo.

---

## 6. Before you upload — the honest gate

Do not upload until the §7 checklist below has been run **on a real
phone**, with a real bot for step 5. Right now none of it has been. The code is
complete and every test passes, but no line of the Android native layer has
ever executed on a physical device: not the foreground service, not the screen
receiver, not the accelerometer, not the auto-PIN pairing, and not the alarm.

Tests prove the logic. They cannot prove that Xiaomi lets the service live.

---

## 7. On-phone checklist

None of this can be closed on a laptop; steps 1–4 need only a phone, step 5 needs a bot.

1. Start a tracked block, lock the screen, walk away → LOCK reads violated,
   verified minutes stop while claimed minutes keep going.
2. Swipe the app away mid-block → the ongoing notice stays and the block keeps
   counting. **This is the one that proves the cached engine works**; if the
   block dies here, `MainActivity.provideFlutterEngine` is the place to look.
3. Grant usage access in More, open another app mid-block → APPS reads violated.
   Revoke it → APPS reads **unavailable**, excluded rather than failed.
4. Leave a 90-minute block running on a Xiaomi/Oppo/Vivo phone with the screen
   off. If it dies, the autostart card in More is the fix — and if the card did
   not appear, `PowerSettingsPlugin.AUTOSTART_INTENTS` is missing that ROM.
5. **With a bot:** power it on, open the app, tap it once → paired and connected
   with **no PIN prompt**. Cut power → badges go unavailable within ~15 s, not
   stale-holding. Power back on → it reconnects on its own.

The alarm has still never fired on a phone. Check it in the same session.
