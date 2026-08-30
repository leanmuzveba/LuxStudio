# LuxStudio

LuxStudio ("Higherlife Custom Video Studio") turns 1–2 hour sermon/teaching
recordings into polished, captioned, branded 9:16 short clips: import a
recording, let AI strip silence and auto-caption it, review AI-ranked clip
candidates, then share a finished clip with AI-generated social copy.

Two parts, one repo:

- **`lib/`** — the Flutter Web client (no native Android/iOS build; see
  "Platform decision" in `CLAUDE.md`).
- **`backend/`** — a thin Python/FastAPI service that holds the Gemini API
  key and runs FFmpeg server-side. Neither the key nor an ffmpeg binary ever
  ships to the browser.

The design source of truth is the static HTML/CSS kit in `ui_kit/`
(home/analyse/editor/clips/share/settings) — the app is built to match it
exactly. `CLAUDE.md` has the full project brief; `PIVOT_PLAN.md` has the
phased migration history from the original native-Android build to this
architecture.

## Screens

- **Home** — recent teachings list, "New Sermon Project" CTA.
- **Analyse** — automatic pipeline (silence removal → audio enhancement →
  AI clip identification → auto-captioning) with a live progress UI.
- **Editor** — 9:16 preview (cropped from the source, matching the export
  aspect exactly), transport controls, segment timeline, transcript list.
- **Clips** — AI-ranked short-form clip candidates with viral-score badges.
- **Share** — platform picker, AI-generated caption, branding toggle,
  save/share a rendered clip.
- **Settings** — church profile, contact & service times, default caption
  template, default hashtags, giving-info toggle (off by default).

## Project layout

```
lib/
  main.dart                    # routes, AppStateScope
  state/app_state.dart         # single ChangeNotifier driving every screen
  screens/                     # one file per screen above
  services/
    api_client.dart            # thin HTTP client to the backend
    project_store.dart         # shared_preferences-backed project persistence
    brand_settings_store.dart  # shared_preferences-backed church/brand settings
    media_import_service.dart  # file_picker -> backend upload
  models/                      # VideoProject, AiClip, TranscriptSegment,
                                # SilenceRange, SocialCopy, CaptionStyle,
                                # BrandSettings, ...
  theme/lux_theme.dart         # design tokens (colors, Inter font via
                                # google_fonts) + lib/theme/phosphor_icons.dart
  widgets/                     # shared LuxCard/LuxButtons/LuxBottomNav/...
test/
  widget_test.dart             # boots the app with fake AppState/ApiClient
  services/                    # pure-logic unit tests

backend/
  app/
    main.py                    # FastAPI app, CORS, routers
    config.py                  # env-driven settings (GEMINI_API_KEY, etc.)
    storage.py                 # disk-backed per-project storage + TTL sweep
    routers/                   # projects, analyse, social, exports, brand
    services/
      gemini_client.py         # transcription, clip suggestions, social copy
      ffmpeg_client.py         # probe, silence detection/removal, export
  tests/                       # pytest — gemini_client, ffmpeg_client, brand
```

## Running it

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows; source .venv/bin/activate elsewhere
pip install -r requirements.txt
```

Create `backend/.env` (or set real env vars):

```
GEMINI_API_KEY=your-key-here
# Optional: STORAGE_DIR, TTL_HOURS, ALLOWED_ORIGINS
```

FFmpeg must be on `PATH` for the analyse pipeline and exports to actually
work (the backend degrades gracefully without it — uploads still succeed,
probing/analysing/exporting fail with a clear error).

```bash
uvicorn app.main:app --reload
```

Serves on `http://localhost:8000` — the Flutter client's default backend URL.

### Flutter client

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

To point at a backend that isn't on `localhost:8000`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://your-backend.example.com
```

### Backend tests

```bash
cd backend
.venv\Scripts\python.exe -m pytest -q
```

## Design tokens

Dark background `#1A1A1A`, body text `#D4B48C`, gold gradient
`#F4A823 → #F5AE1F` for CTAs/active states, glass card
`rgba(51,50,55,0.8)` (approximated as an opaque fill in Flutter — see
`lib/theme/lux_theme.dart`'s doc comment). Inter font throughout, Phosphor
icons for shared chrome (see `lib/theme/phosphor_icons.dart` for why that's
hand-rolled rather than using the `phosphor_flutter` package's own API).
