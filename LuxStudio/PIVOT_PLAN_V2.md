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

## Open decisions — resolve before Phase 24 (functionality) starts

These fell out of comparing the desktop mockups against the current mobile app and backend. None
are blocking the remaining mockup-collection phases, but Phase 24+ can't start until they are.

1. **Auth/Login is new scope.** The backend currently has explicitly "no auth" and no user-account
   model at all (`CLAUDE.md`). A real login page means deciding: full multi-user accounts (sign
   up/in, password or OAuth, per-user data isolation) vs. a lightweight single-church gate (one
   shared passcode, no real account system). This changes backend scope significantly either way.
2. **Media Library implies a bigger data model than "one video per project."** The backend today
   stores everything under `storage/<project_id>/` — one project, one source video. The Media
   Library mockup (folders, assets reused across projects, a storage quota footer) implies an
   asset library that outlives any single project. Needs its own backend entity.
3. **Exports as its own nav destination implies an export history/queue** — but Phase 12 of V1
   deliberately deleted that (`exportJobs`, batch export) in favor of one single-clip
   export/share flow. Decide: reintroduce export history (now scoped above individual projects,
   like the media library), or keep "Exports" as a shortcut into the existing Share screen.
4. **Subtitles as its own nav destination** conflicts with V1's decision (Phase 9) to fold
   captions into the automatic Analyse pipeline + the Editor's transcript panel, with the old
   standalone Captions screen deleted. Decide whether desktop gets real standalone subtitle
   styling controls (font/position/timing) that don't exist anywhere yet, or is just a reskin of
   the existing transcript editor.
5. **IA mismatch**: the desktop sidebar nav shown so far is Editor / Media Library /
   AI Highlights / Subtitles / Exports / Settings — the mobile bottom-nav is Home / Editor /
   Clips / Settings + an Import FAB. These need reconciling: keep both navs intentionally
   different per breakpoint (fine, but should be a deliberate choice, not a drift), change mobile
   to match, or collapse desktop to match mobile's four destinations.

## Phases

### Mockup-collection stream (current)

- **Phase 16 — Desktop Editor mockup** — DONE (`ui_kit/editor_desktop/`, commit `b1c1d28`)
- **Phase 17 — Desktop Media Library mockup** — DONE (`ui_kit/media_library_desktop/`, commit `2c73b2d`)
- **Phase 18 — Desktop AI Highlights mockup** — waiting on design from user
- **Phase 19 — Desktop Subtitles mockup** — waiting on design from user
- **Phase 20 — Desktop Exports mockup** — waiting on design from user
- **Phase 21 — Desktop Settings mockup** — waiting on design from user
- **Phase 22 — Splash screen mockup** — waiting on design from user
- **Phase 23 — Login page mockup** — waiting on design from user; surfaces Decision #1 above

### Functionality stream (after all of the above)

- **Phase 24 — Responsive breakpoint architecture.** A shared width-based layout switch
  (`LayoutBuilder`/`MediaQuery`) so each screen picks its mobile or desktop widget tree off one
  `AppState`, with no logic duplicated. A reusable "desktop shell" (sidebar nav + header),
  analogous to the existing `bottom_nav_scaffold.dart` for mobile. Resolve Decision #5 here.
- **Phase 25 — Auth & Splash/Login functionality.** Resolve Decision #1, then build whatever that
  implies: splash screen as a route gate, login page wired to the chosen auth strategy, backend
  auth endpoints if real accounts are in scope.
- **Phase 26 — Desktop Editor functionality.** Wire `ui_kit/editor_desktop/` to real `AppState`:
  playback and transcript-driven cuts (already exist), tool rail scoped to what's realistically
  buildable (crop/pan likely stay inert, same as mobile's Audio/AI Cuts/Overlay), multi-track
  timeline cosmetic-only unless real multi-track editing gets scoped in.
- **Phase 27 — Media Library functionality.** Resolve Decision #2, add backend asset-library
  endpoints (folders, list/upload/delete), wire the desktop screen for real.
- **Phase 28 — AI Highlights functionality (desktop).** Reskin of the existing AI clip
  suggestion feature (`ai_clips_screen.dart`) onto its desktop mockup.
- **Phase 29 — Subtitles functionality (desktop).** Resolve Decision #4, then wire it.
- **Phase 30 — Exports functionality (desktop).** Resolve Decision #3, then wire it.
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
