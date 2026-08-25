# LuxStudio (Flutter rebuild)

An original Flutter/Dart implementation of the **LuxStudio** app concept — an
AI-assisted sermon-to-social video editor: import a raw sermon recording, let
AI strip silence and clean up audio, review auto-captions, pick from
AI-ranked "viral" short-form clips, and export straight to Reels, TikTok,
Shorts, or Stories.

This was reverse-engineered from a written product/design description (four
key screens: **Import & AI Processing → Video Editor → AI Suggested Clips →
Export & Share**) — there was no existing source to copy from, so every file
here is original Dart written to reproduce that *behavior and flow*, not a
port of anyone else's code.

## What's implemented

- **Screen 1 — Import & AI Processing**: an import prompt, then a live
  circular progress ring animating through the 4-stage AI pipeline
  (silence removal → audio enhancement → clip identification →
  auto-captioning).
- **Screen 2 — Video Editor**: a 9:16 preview pane, a 4-tab tool bar
  (Captions / Audio / AI Cuts / Overlays), a scrubbable timeline strip that
  visualizes audio chunks vs. trimmed silence gaps, and a scrollable,
  inline-editable transcript.
- **Screen 3 — AI Suggested Clips**: clips ranked by a mock "viral score,"
  each with a 9:16 thumbnail, title, timestamp range, and an
  **Edit & Export** action.
- **Screen 4 — Export & Share**: multi-select destination picker, an
  AI-generated caption chooser, branding-preset toggles, and a share action.

State flows through a single lightweight `AppState` (`ChangeNotifier`),
exposed app-wide via a small `InheritedWidget` (`AppStateScope`) — no
external state-management package required.

## Project layout

```
lib/
  main.dart                    # app entry point, routes, AppStateScope
  theme/app_theme.dart         # colors, gradients, text/typography tokens
  models/                      # VideoProject, ProcessingStep, TranscriptSegment,
                                # AiClip, ExportDestination, BrandingPreset
  state/app_state.dart         # ChangeNotifier driving all 4 screens
  screens/
    import_processing_screen.dart
    video_editor_screen.dart
    ai_clips_screen.dart
    export_share_screen.dart
  widgets/                     # reusable pieces: gradient button, viral score
                                # badge, circular step progress, timeline
                                # strip, transcript list
test/
  widget_test.dart             # smoke tests for the flow
```

## Running it

This environment doesn't have the Flutter SDK installed, so the code was
written and hand-reviewed carefully but not run through `flutter analyze` —
do that first thing after unzipping. To get it onto an Android device or
emulator:

```bash
# 1. Unzip this project, then from inside the folder:
flutter create .          # generates android/, plus a build config that
                           # matches your installed Flutter/Gradle/SDK setup
                           # (kept out of this bundle since it's machine- and
                           # version-specific boilerplate, not app logic)

flutter pub get
flutter analyze           # should be clean
flutter test               # runs test/widget_test.dart

flutter run                # launches on a connected Android device/emulator
```

If `flutter create .` reports conflicts on `pubspec.yaml` or
`analysis_options.yaml`, keep the versions already in this bundle — they're
intentional (dark theme dependencies, `flutter_lints`).

## Wiring up the real thing

Everything here runs on mock/simulated data so the full flow is demoable
with zero backend. The natural next integration points are called out with
comments in `pubspec.yaml` and in the code:

- **Video import**: swap the mock `_beginImport` trigger in
  `import_processing_screen.dart` for `file_picker` (or
  `image_picker`'s video mode).
- **Real preview/scrubbing**: replace the placeholder preview pane in
  `video_editor_screen.dart` with `video_player` + a scrub-synced
  `VideoPlayerController`.
- **Actual AI processing**: replace `AppState._seedTranscriptAndClips()`
  with calls to your speech-to-text / silence-detection / highlight-scoring
  backend (or an on-device pipeline via `ffmpeg_kit_flutter`).
- **Native share sheet**: swap the `SnackBar` in
  `export_share_screen.dart`'s `_confirmShare` for `share_plus`.

## Design notes

The visual language is a dark, editing-suite surface (`#0B0B10` background,
`#16161D` cards) with a single warm pink→violet accent gradient
(`AppColors.accentGradient`) reserved for primary actions and the viral-score
badge, whose color shifts hotter (pink/orange) the higher the score. All of
this lives in `lib/theme/app_theme.dart` as reusable tokens rather than
inlined per-screen, so retheming is a one-file change.
