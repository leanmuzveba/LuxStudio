# LuxStudio Backend

Thin FastAPI service that holds the Gemini API key and runs FFmpeg
server-side, so neither ever ships in the Flutter Web client. No database —
uploaded video and intermediate artifacts live on local disk under
`storage/<project_id>/`, tracked by a `meta.json` sidecar per project, swept
by TTL on startup.

## Prerequisites

- Python 3.11+
- FFmpeg available on `PATH` (needed from Phase 3 onward, not yet by this
  scaffold)

## Setup

```
cd backend
python -m venv .venv
.venv\Scripts\activate      # Windows
pip install -r requirements.txt
```

Create a `.env` file (or set real environment variables) in `backend/`:

```
GEMINI_API_KEY=your-key-here
# Optional overrides:
# STORAGE_DIR=./storage
# TTL_HOURS=48
# ALLOWED_ORIGINS=http://localhost:5000,http://localhost:8080
```

## Run

```
uvicorn app.main:app --reload
```

Serves on `http://localhost:8000` by default — this is the Flutter client's
default backend base URL in dev.

## Endpoints so far

- `GET /health` — liveness check.
- `POST /projects` — multipart upload (`file`), creates a project folder and
  stores the source video.
- `GET /projects/{project_id}` — returns the project's `meta.json`.

Gemini and FFmpeg endpoints land in Phases 2-3.
