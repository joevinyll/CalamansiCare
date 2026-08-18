# CalamansiCare Flutter UI

This folder contains the first Flutter UI implementation for the CalamansiCare capstone app.

## What Is Included

- `pubspec.yaml` with planned Flutter dependencies
- `lib/main.dart` with the full static UI flow:
  - Welcome and language selection
  - Home dashboard
  - Start check
  - Camera/photo guide
  - AI scanning
  - Diagnosis result
  - Treatment guide
  - Report preview and consent
  - Offline queue
  - History
  - Settings
  - Barangay inbox

## Important

This folder was created manually because the Flutter command was not visible in the terminal yet.

Before running the app, open this folder in VS Code and make sure Flutter works:

```bash
flutter --version
flutter doctor
```

If Flutter works, run this inside the `CalamansiCare` folder:

```bash
flutter create .
flutter pub get
flutter run
```

When Flutter asks whether to overwrite `lib/main.dart` or `pubspec.yaml`, choose **No** or keep the existing files, because these files already contain the CalamansiCare UI.

## Current Tech Decisions

| Area | Decision |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Offline AI | On-device model |
| Offline database | SQLite |
| Reporting backend | Supabase |
| Languages | English, Tagalog, Cebuano |

## Disease Labels

Use these exact labels everywhere:

1. Healthy
2. Citrus Canker
3. HLB / Greening
4. Anthracnose
5. Sooty Mold
6. Citrus Scab
7. Brown Rot
8. Nutrient Deficiency

## Next Development Steps

1. Confirm Flutter is installed and added to PATH.
2. Run `flutter create .` to generate Android/iOS/web project files.
3. Run `flutter pub get`.
4. Run the app on Chrome, emulator, or Android phone.
5. Split `lib/main.dart` into folders later when the UI is stable.
6. Connect real camera/gallery logic.
7. Connect offline AI model.
8. Connect SQLite for history and queue.
9. Connect Supabase for report sending.

"# CalamansiCare" 
