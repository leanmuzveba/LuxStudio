# LuxStudio — Project Context

## What this is
Higherlife Custom Video Studio ("LuxStudio"): turns 1–2 hour sermon/teaching videos into
polished, captioned, branded 9:16 short clips with minimal manual editing. Full PRD:
`initial_docs/` in this repo (or see LuxStudio_PRD.pdf).

## Platform decision (supersedes the PRD's "Android-first Flutter" direction)
- **Flutter Web**, mobile-responsive. Not a native Android build.
- The reference UI mockups use a phone-shell pattern (max-width ~430px, centered) that
  already degrades gracefully to wider viewports — build on that pattern rather than a
  from-scratch responsive redesign.

## UI reference — do not improvise on visual design
A full 6-screen static HTML/CSS UI kit exists and is the source of truth for the Flutter
build (Home, Analyse, Editor, Clips, Settings, Share). Match it exactly rather than
reinterpreting. Design tokens:
- Background `#1A1A1A` · body text `#D4B48C` · white `#FFFFFF`
- Gold gradient (CTAs, FAB, active states): `#F4A823 → #F5AE1F`
- Glass card: `rgba(51,50,55,0.8)` bg, 12px blur, `rgba(108,77,21,0.3)` border
- Font: Inter · Icons: Phosphor · Heavy rounded corners (16–40px)
- Bottom nav: Home / Editor / (raised gold FAB) / Clips / Settings

The `Settings` screen (Church Profile, Contact & Service Times, Default Caption
Template, Default Hashtags, Giving Information toggle) was built to match the other
five — check this repo's `settings/` folder alongside `home/`, `editor/`, `analyse/`,
`clips/`, `share/`.

## Architecture decision: Gemini instead of Whisper + separate LLM
The original PRD's backend (FastAPI + Postgres + Whisper + separate LLM service) is
being simplified: **Gemini API** likely absorbs transcription, AI clip scoring, and
summary/hashtag generation in one call.

**Non-negotiable:** the Gemini API key must never live in client code. Flutter Web
ships all its code to the browser, so anything embedded there is fully extractable via
dev tools. Required shape:

```
Flutter Web client  →  thin backend (holds Gemini key, runs FFmpeg jobs)  →  Gemini API
```

FFmpeg (or equivalent) still has to run server-side for actual silence removal, cutting,
and export rendering — Gemini can analyze and suggest, but can't edit video.

## PRD highlights worth keeping visible
- Original video is never modified (data safety requirement)
- Giving information is **off by default**, only appended with an explicit toggle
- 3 caption templates, customizable, saved as project default
- Primary export: 1080×1920 9:16 MP4
- AI output (summaries, clip picks) is always human-reviewed before publish, never
  presented as guaranteed factual

## Default church config (from PRD §8)
- Church Name: Higherlife Commission
- Address: 65 11th Road, Kew, Johannesburg, Gauteng, South Africa, 2090
- Sunday Service: 9:00 AM – 12:00 PM · Thursday Service: 6:00 PM – 8:00 PM
- Default hashtags: #wordsofwisdom #lifeinthespirit #lifeinthespiritseminar
- Giving account (optional, toggle-gated): FNB Account 62777808208

## Not yet decided — settle these early in the session
- How much of the original FastAPI/Postgres/worker-queue backend survives vs. gets
  replaced by a lighter proxy
- Whether the existing code in this repo's Flutter folder is a rebuild target or gets
  replaced wholesale (review it first before deciding)
