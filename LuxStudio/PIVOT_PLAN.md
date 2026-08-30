# LuxStudio Full Pivot: Reskin + Flutter Web + Backend

## Context

LuxStudio just finished a 12-phase "Lux" theme redesign (native Android, fully on-device, Sora/Manrope fonts) matching a generic mockup artifact. A new brief (`CLAUDE.md`) supersedes that direction entirely: the real source of truth is a church-branded ("Higherlife Commission") 6-screen static HTML/CSS UI kit uploaded as `LuxStudio2.zip` + `LuxStudio_settings_screen.zip`, unzipped into `ui_kit/` (home, analyse, editor, clips, share, settings). CLAUDE.md also mandates two platform-level changes the current architecture can't support as-is:

- **Flutter Web**, not native Android.
- A **thin backend** holding the Gemini API key (currently shipped client-side via `flutter_secure_storage` — fatal on Web, since browser-shipped code is fully extractable) and running **FFmpeg server-side** (currently on-device via `ffmpeg_kit_flutter_new`, which has no Flutter Web equivalent at all).

Two information-architecture changes fall out of the new mockup and are treated as decided (not just cosmetic), because the goal is to match the UI kit exactly:

- **Analyse** (new screen: circular progress ring + step checklist) replaces the current manual `silence_screen.dart` + `captions_screen.dart` with one automatic backend-driven pipeline (silence removal → audio enhancement → AI clip ID → auto-captioning).
- **Share** (new screen: single combined caption blob + platform picker + Save/Share Now) replaces `social_screen.dart`'s 4 structured fields and `export_share_screen.dart`'s batch multi-clip export list with one single-clip share/export flow.

## Backend architecture

- **Stack**: Python FastAPI, single service, no Postgres, no worker queue. New `backend/` folder at repo root (same repo).
- **Storage**: no database. Uploaded video + intermediate artifacts live on local disk under `backend/storage/<project_id>/`, tracked via a JSON sidecar per project; a TTL sweep (~48h inactivity) deletes stale project folders. No auth.
- **Gemini key**: read from a server-side env var only, never returned to the client.
- **Dev workflow**: backend runs locally via `uvicorn` (`http://localhost:8000` default). Real cloud hosting is a later decision, out of scope here.
- **Client persistence**: Flutter Web keeps lightweight project metadata (id, title, timestamps, status, backend `project_id` reference) via `shared_preferences`. Media itself is never persisted long-term client-side; resuming a project re-fetches state from the backend by id.

## Phases

Each phase = one commit + push. `flutter analyze` (Flutter phases) / backend tests (backend phases) clean before each commit. Full end-to-end browser walkthrough deferred to the final phase.

### Phase 0 — Baseline commit
Track `CLAUDE.md`, `ui_kit/`, and this plan. Leave the two source zips untracked (already extracted).

### Phase 1 — Backend scaffold
FastAPI skeleton: health check, CORS, project create/upload, disk layout, TTL sweep stub.
`backend/app/main.py`, `config.py`, `storage.py`, `routers/projects.py`, `requirements.txt`, `README.md`.

### Phase 2 — Backend: Gemini proxy endpoints
Port `gemini_service.dart`'s transcribe/suggestClips/generateSocialCopy server-side.
`backend/app/services/gemini_client.py`, `routers/analyse.py`, `routers/social.py`, `tests/test_gemini_client.py`.

### Phase 3 — Backend: FFmpeg endpoints
Port `ffmpeg_service.dart`'s probe/detectSilence/removeRanges/extractAudio/exportClip server-side; wire the full automatic pipeline.
`backend/app/services/ffmpeg_client.py`, `routers/exports.py`, `tests/test_ffmpeg_client.py`.

### Phase 4 — Flutter Web platform bring-up
Add the web target, get the current app building/running in a browser, establish backend base-URL config.
`web/` (generated), `lib/services/api_client.dart`, `pubspec.yaml` (+`http`).

### Phase 5 — AppState/persistence rework (highest-risk phase) — DONE, larger than planned
Drop `dart:io`, replace file-based persistence and direct Gemini/FFmpeg calls with backend calls.
Rewrite `lib/services/project_store.dart` (shared_preferences-backed); delete `ffmpeg_service.dart`, `gemini_service.dart`, `secure_settings.dart` (+ their tests); rewrite `lib/state/app_state.dart` (adds `runAnalysePipeline()`/`analyseStatus`/`analyseStep`/`analysePercent`/`analyseError`, keeps `detectSilence`/`applySilenceRemoval`/`transcribeAudio`/`generateClipSuggestions` as clearly-commented **Phase 5→9 transitional aliases** funneling into the one atomic backend pipeline, since the backend has no standalone per-step endpoints by design); update `lib/models/video_project.dart` (`sourcePath`/`workingPath` → `backendProjectId`); `pubspec.yaml` swaps.

Necessarily absorbed most of Phase 6's original scope too, since `ffmpeg_service.dart`'s deletion cascaded into `media_import_service.dart` (now uploads bytes via `ApiClient`), `video_editor_screen.dart` (`VideoPlayerController.networkUrl` against `AppState.currentVideoUrl`, "Restore Original" button removed — no client-tracked original/working distinction left), `export_share_screen.dart` (share via `AppState.downloadExport()` fetching bytes from the backend, not a local path), `import_screen.dart` (dropped local file-size lookup), and `settings_screen.dart` (its entire prior purpose — Gemini key entry — is gone; reduced to a placeholder pending Phase 13's real rebuild). Backend gained a best-effort probe-on-upload and `GET /projects/{id}/video`.

### Phase 6 — Web-safe branding/logo storage — DONE, narrower than planned
Everything else Phase 6 originally listed was already done in Phase 5 (see above). What was left: no backend endpoint existed for the global (non-project-scoped) brand logo. Added `backend/app/routers/brand.py` (`POST`/`GET /brand/logo`, stored under `storage/_brand/`, outside the TTL sweep) + tests. Rewrote `brand_settings_store.dart` (shared_preferences-backed, logo upload via `ApiClient`), `brand_settings.dart` (`logoPath`→`logoUrl`), `branding_screen.dart` (`Image.network` off `AppState.backendBaseUrl`, no more `dart:io`/`Platform`). Removed `path_provider` from `pubspec.yaml` (fully unused after these two phases).

**Checkpoint**: working Flutter Web app talking to the real backend end-to-end, still old theme. `flutter build web` verified.

### Phase 7 — Design system swap — DONE
Retheme tokens/fonts app-wide: `lib/theme/lux_theme.dart` (new palette, `GoogleFonts.inter` under the existing `sora`/`manrope` method names — a rename would've touched every screen, out of scope here), `lib/widgets/lux_card.dart` (new optional `radius` override for later per-screen reskins), `lux_icon_button.dart` (circular now, matching the kit), `lux_bottom_nav.dart`/`bottom_nav_scaffold.dart` (rebuilt: glass 96px bar, 40px top corners, raised gold FAB → `/import`; tab set is Home/Editor/Clips/Settings — Branding dropped as its own tab per plan, folded into Settings in Phase 13; Editor/Clips already tolerated a null `AppState.project` so no extra guard work was needed), `lux_app_bar.dart` (back-button icon).

**`phosphor_flutter` 2.1.0 workaround**: the package's Dart API (`PhosphorIconsRegular` etc.) fails to compile on this Flutter SDK — `PhosphorIconData extends IconData`, and `IconData` is now a `final class`, with no newer package version published yet. `flutter analyze` did NOT catch this (only `flutter test`/`flutter build web` did) — worth remembering analyze alone isn't sufficient for a real compile check. Fix: kept `phosphor_flutter` as a pubspec dependency purely for its bundled font assets, and added `lib/theme/phosphor_icons.dart` — hand-picked icons as raw `IconData(codepoint, fontFamily: ..., fontPackage: 'phosphor_flutter')`, codepoints read from the installed package's own source. Extend that file (not the package's own classes) as later phases need more icons.

### Phase 8 — Reskin: Home
`lib/screens/home_screen.dart`.

### Phase 9 — Build: Analyse (retires silence + captions)
New `lib/screens/analyse_screen.dart`; delete `silence_screen.dart`, `captions_screen.dart`; update `main.dart` routes, `app_state.dart`.

### Phase 10 — Reskin: Editor
`lib/screens/video_editor_screen.dart` (read `ui_kit/editor/index.html` directly — most spec is inline Tailwind, not CSS).

### Phase 11 — Reskin: Clips
`lib/screens/ai_clips_screen.dart`.

### Phase 12 — Build: Share (retires social + batch export)
New `lib/screens/share_screen.dart`; delete `social_screen.dart`, `export_share_screen.dart`, `export_job.dart`; update `main.dart`, `app_state.dart`, `social_copy.dart`.

### Phase 13 — Reskin + extend: Settings
Consolidate `branding_screen.dart` into `settings_screen.dart`; extend `brand_settings.dart` with church profile/service times/caption template default/hashtag defaults/giving toggle, seeded from CLAUDE.md's default church config.

### Phase 14 — Cleanup pass
Update `test/widget_test.dart`, `README.md`; sweep dead references.

### Phase 15 — End-to-end verification
Manual pass: `uvicorn` backend + `flutter run -d chrome`, full walkthrough, confirm export produces a valid 1080×1920 MP4.

## Sequencing rationale
- Phases 1-3 (backend) built/tested independent of Flutter first.
- Phase 5 isolated before visual work, so Phases 8-13 build against the final AppState shape once.
- Phases 9 and 12 are new-screen builds, not reskins.
- Deletions are spread across the phases that replace them, not batched.
