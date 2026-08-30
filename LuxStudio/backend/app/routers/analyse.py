"""Automatic analyse pipeline the Analyse screen's progress UI drives:
silence removal -> audio enhancement -> AI clip identification ->
auto-captioning, run as one backend job per project.

This phase establishes the endpoint contract and progress data shape only.
The pipeline itself needs ffmpeg_client.py (silence detection/removal,
audio extraction), which lands in Phase 3 — wiring the real step-by-step
run happens there. Calling POST here today records a "not_implemented"
status rather than pretending to run steps that don't exist yet.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app import storage

router = APIRouter(prefix="/projects", tags=["analyse"])

STEPS = ["silence_removal", "audio_enhancement", "clip_identification", "captioning"]


def _idle_status() -> dict:
    return {"status": "not_started", "step": None, "percent": 0, "error": None}


@router.post("/{project_id}/analyse")
async def start_analyse(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")

    # TODO(Phase 3): kick off the real pipeline (detect_silence ->
    # remove_ranges -> extract_audio -> transcribe -> suggest_clips) as a
    # background task, updating meta["analyse"]'s step/percent as it runs.
    status = {"status": "not_implemented", "step": None, "percent": 0, "error": None}
    meta["analyse"] = status
    storage.write_meta(project_id, meta)
    return status


@router.get("/{project_id}/analyse/status")
async def analyse_status(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return meta.get("analyse", _idle_status())
