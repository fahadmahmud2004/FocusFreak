# FocusFreak — Android app

Offline-first focus and time-management app, and the companion/controller for the FocusFreak desk bot.

```bash
flutter pub get
flutter analyze        # must be clean
flutter test           # must be green
flutter run            # Android device
flutter run -d web-server --web-port=5599   # quick visual check, no Bluetooth
dart run build_runner build --delete-conflicting-outputs   # after Drift schema changes
```

Architecture and engineering rules: [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md).
Wire protocol: [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md). Product spec: [`../docs/APP_SPEC.md`](../docs/APP_SPEC.md).
