# LuxStudio V2: Desktop Expansion + Auth

## Context

The V1 pivot (`PIVOT_PLAN.md`, Phases 0-14) delivered a phone-shell Flutter Web app matching
the original 6-screen `ui_kit/` (Home, Analyse, Editor, Clips, Settings, Share), talking to a
FastAPI + FFmpeg + Gemini backend. Its final step, **Phase 15 (end-to-end verification), was
never actually run** — that's still outstanding.

Starting 2026-09-05, a second work stream began: the user is supplying hand-designed
**desktop-viewport** (wide, sidebar-nav) mockups screen-by-screen, explicitly UI-only for now —
recolor onto the real brand tokens, commit to `ui_kit/<screen>_desktop/` as reference, no Flutter
wiring yet. Once every desktop screen plus a Splash screen and a Login page are in hand, the plan
moves to a single functionality pass covering both breakpoints.

**Desktop mockup convention** (established across Phases 16-17, keep following it):
- Check whether the file's hex colors already match the brand swatch (`colors.png`:
  `#1A141A` / `#423738` / `#8E5915` / `#D3AF85` / `#F4B315` / `#E59312`, ≈ `LuxColors` in
  `lib/theme/lux_theme.dart`) — full recolor if not (Editor), light touch-up if so (Media Library).
- Always swap any placeholder/drawn logo mark for the real `icon.png` (copied in from
  `ui_kit/home/icon.png`).
- Keep every accent color inside the brand's single gold/bronze/tan family — no introduced hues
  (blue, green, red, etc.), even if the source file has them; differentiate by icon/weight/opacity
  instead, matching how the AI-clip tags and media-type badges were normalized.
- Publish an Artifact preview before asking to commit (inline the CSS + base64 the logo for
  standalone preview files that use external `<link>`/`<img>` references); commit only once the
  user has actually seen it and confirmed.

## Decisions (resolved 2026-09-06, before Phase 24 starts)

These fell out of comparing the desktop mockups against the current mobile app and backend.

1. **Auth/Login.** ✅ **Single shared church passcode** — one shared password/PIN gates the whole
   app for the church's media team. No signup flow, no per-user accounts, no per-user data
   isolation. Backend scope: one gate check before the app loads, not a user table or session
   system.
2. **Media Library data model.** ✅ **Real asset library** — a new backend entity independent of
   any single project: folders, assets reused across multiple projects, a storage quota footer.
   Replaces the current `storage/<project_id>/`-only, one-video-per-project model; projects
   reference library assets rather than owning private copies.
3. **Exports as its own nav destination.** ✅ **Reintroduce export history/queue** — scoped above
   individual projects, like the media library: past exports, in-flight render status, re-download/
   re-share old exports. Un-deletes and extends what V1's Phase 12 removed (`exportJobs`, batch
   export), rather than just shortcutting into Share.
4. **Subtitles as its own nav destination.** ✅ **Real standalone subtitle controls** — new
   functionality: font/style, position, and timing controls for captions, as their own screen. Not
   just a reskin of the Editor's transcript panel (which V1's Phase 9 built to replace the old
   deleted standalone Captions screen) — this adds real caption-styling capability on top of it.
5. **IA mismatch (desktop sidebar vs. mobile bottom-nav).** ✅ **Deliberately different per
   breakpoint** — desktop's sidebar (Editor / Media Library / AI Highlights / Subtitles / Exports /
   Settings) stays as-is, matching its richer feature set from decisions #2-4 above; mobile's
   bottom-nav stays lean (Home / Editor / Clips / Settings + Import FAB) for thumb reach. This is
   the intentional design, not drift to fix later.

## Phases

### Mockup-collection stream (current)

- **Phase 16 — Desktop Editor mockup** — DONE (`ui_kit/editor_desktop/`, commit `b1c1d28`)
- **Phase 17 — Desktop Media Library mockup** — DONE (`ui_kit/media_library_desktop/`, commit `2c73b2d`)
- **Phase 18 — Desktop AI Highlights mockup** — DONE (`ui_kit/ai_highlights_desktop/`, commit `37ddcb6`)
- **Phase 19 — Desktop Subtitles mockup** — DONE (`ui_kit/subtitles_desktop/`, commit `91754ae`)
- **Phase 20 — Desktop Exports mockup** — DONE (`ui_kit/exports_desktop/`, commit `546fe3d`)
- **Phase 21 — Desktop Settings mockup** — DONE (`ui_kit/settings_desktop/`)
- **Phase 22 — Splash screen mockup** — DONE (`ui_kit/auth/`, commit `d377e63`)
- **Phase 23 — Login page mockup** — DONE (`ui_kit/auth_desktop/`, commit `d377e63`)

All mockup-collection phases (16-23) are now complete, and all 5 decisions above are resolved.
Phase 24 (functionality stream) is next.

### Functionality stream (after all of the above)

- **Phase 24 — Responsive breakpoint architecture.** DONE. `lib/theme/breakpoints.dart` adds a
  single 900px width threshold (`Breakpoints.isDesktop`); `lib/main.dart`'s `_ResponsiveHome` picks
  `DesktopShellScaffold` (new) or the existing `BottomNavScaffold` off it, per Decision #5 (the two
  navs stay intentionally different, not reconciled into one). The old app-wide 430px phone-shell
  cap moved out of `MaterialApp.builder` into a small `PhoneShell` widget applied per-route instead
  (`BottomNavScaffold` and every pushed "new project" flow route), so it no longer also squeezes
  the desktop shell. `DesktopShellScaffold` (`lib/widgets/desktop_shell_scaffold.dart`) is the new
  sidebar (logo, 5 nav destinations, pinned Settings, a "Current Project" card reading real
  `AppState`) + content pane; only Editor, AI Highlights, and Settings have anything to show yet
  (the existing mobile screens, reused as-is and centered at phone-shell width — no logic
  duplicated, just not desktop-shaped yet), Media Library/Subtitles/Exports show a "lands in Phase
  N" placeholder since those features don't exist at all yet. Covered by a new widget test
  (simulates a 1400×900 window, confirms the sidebar shows instead of the bottom nav).
- **Phase 25 — Auth & Splash/Login functionality.** Splash screen as a route gate; login page
  wired to a single shared church passcode (Decision #1) — one backend gate-check endpoint, no
  user table/sessions.
- **Phase 26 — Desktop Editor functionality.** Wire `ui_kit/editor_desktop/` to real `AppState`:
  playback and transcript-driven cuts (already exist), tool rail scoped to what's realistically
  buildable (crop/pan likely stay inert, same as mobile's Audio/AI Cuts/Overlay), multi-track
  timeline cosmetic-only unless real multi-track editing gets scoped in.
- **Phase 27 — Media Library functionality.** Add backend asset-library endpoints (folders,
  list/upload/delete, storage quota) per Decision #2, wire the desktop screen for real; projects
  reference library assets instead of owning private copies.
- **Phase 28 — AI Highlights functionality (desktop).** Reskin of the existing AI clip
  suggestion feature (`ai_clips_screen.dart`) onto its desktop mockup.
- **Phase 29 — Subtitles functionality (desktop).** Build real standalone subtitle styling
  controls (font/style, position, timing) per Decision #4 — new functionality, not just a
  transcript-panel reskin.
- **Phase 30 — Exports functionality (desktop).** Reintroduce export history/queue per Decision
  #3 (scoped above individual projects, like the media library) — past exports, in-flight render
  status, re-download/re-share.
- **Phase 31 — Desktop Settings functionality.** Reskin of the existing `settings_screen.dart`.
- **Phase 32 — End-to-end verification** (supersedes V1's never-run Phase 15). Full manual
  walkthrough at both mobile and desktop widths, backend via `uvicorn`, confirm exports produce a
  valid 1080×1920 MP4, confirm login/auth gate works, confirm media library persists across
  projects.

## Sequencing rationale

- Mockups first, functionality second — same reasoning as V1: build against a final visual/IA
  target once, not iteratively.
- Phase 24 (breakpoint architecture) comes before any individual desktop screen gets wired, so
  Phases 26-31 all build against the same mechanism rather than each inventing one.
- Phase 25 (auth) comes right after the architecture phase and before any other functionality
  work, since login potentially gates everything else.
- Phase 32 closes out both the V1 and V2 verification debt in one pass, since by then both
  breakpoints need walking through anyway.
