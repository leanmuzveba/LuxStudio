"""Automatic analyse pipeline the Analyse screen's progress UI drives:
silence removal -> audio enhancement -> AI clip identification ->
auto-captioning, run as one backend job per project (no worker
queue — a plain background thread is enough at this scale).

Step-to-UI mapping: the mockup's 4 named steps don't line up 1:1 with the
technical pipeline order (clip identification needs a transcript, which
functionally must exist before clips can be suggested). We run the real
work as detect_silence -> remove_ranges -> extract_audio -> transcribe ->
suggest_clips, and report progress against the UI's 4 labels as:
  - "silence_removal"     -> detect_silence + remove_ranges
  - "audio_enhancement"   -> extract_audio
  - "clip_identification" -> transcribe + suggest_clips (the heavy AI work)
  - "captioning"          -> finalizing: the transcript is already fetched
                              by this point, so this step just persists it
                              as the project's caption source for the editor
"""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, HTTPException

from app import storage
from app.services import ffmpeg_client, gemini_client
from app.services.ffmpeg_client import FfmpegError
from app.services.gemini_client import GeminiError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/projects", tags=["analyse"])

STEPS = ["silence_removal", "audio_enhancement", "clip_identification", "captioning"]
_STEP_WEIGHTS = {
    "silence_removal": 25,
    "audio_enhancement": 15,
    "clip_identification": 55,
    "captioning": 5,
}


def _idle_status() -> dict:
    return {"status": "not_started", "step": None, "percent": 0, "error": None}


def _percent_through(step: str) -> int:
    done = STEPS[: STEPS.index(step)]
    return sum(_STEP_WEIGHTS[s] for s in done)


def _set_status(project_id: str, **fields) -> None:
    meta = storage.read_meta(project_id)
    if meta is None:
        return
    status = meta.get("analyse", _idle_status())
    status.update(fields)
    meta["analyse"] = status
    storage.write_meta(project_id, meta)


def _run_pipeline(project_id: str) -> None:
    """Runs synchronously on a background thread (see start_analyse) —
    every ffmpeg/Gemini call here is blocking by design."""
    meta = storage.read_meta(project_id)
    if meta is None:
        return
    project_dir = storage.project_dir(project_id)
    source_path = project_dir / meta["video_filename"]

    try:
        _set_status(
            project_id,
            status="running",
            step="silence_removal",
            percent=_percent_through("silence_removal"),
            error=None,
        )
        silence_ranges = ffmpeg_client.detect_silence(source_path)
        accepted = [r for r in silence_ranges if r.get("accepted", True)]
        working_path = project_dir / "working.mp4"
        ffmpeg_client.remove_ranges(
            source_path=source_path,
            output_path=working_path,
            ranges_to_remove=accepted,
        )

        _set_status(
            project_id, step="audio_enhancement", percent=_percent_through("audio_enhancement")
        )
        audio_path = project_dir / "audio.aac"
        ffmpeg_client.extract_audio(working_path, audio_path)

        _set_status(
            project_id,
            step="clip_identification",
            percent=_percent_through("clip_identification"),
        )
        transcript = gemini_client.transcribe(audio_path.read_bytes(), "audio/aac")
        clips = gemini_client.suggest_clips(transcript)

        _set_status(project_id, step="captioning", percent=_percent_through("captioning"))

        meta = storage.read_meta(project_id) or meta
        meta["silence_ranges"] = silence_ranges
        meta["working_video_filename"] = working_path.name
        meta["transcript"] = transcript
        meta["clips"] = clips
        meta["status"] = "analysed"
        storage.write_meta(project_id, meta)

        _set_status(project_id, status="done", step="captioning", percent=100)
    except (FfmpegError, GeminiError) as exc:
        logger.exception("Analyse pipeline failed for project %s", project_id)
        _set_status(project_id, status="error", error=str(exc))
    except Exception as exc:  # keep the progress UI from hanging forever
        logger.exception("Analyse pipeline crashed for project %s", project_id)
        _set_status(project_id, status="error", error=f"Unexpected error: {exc}")


@router.post("/{project_id}/analyse")
async def start_analyse(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    if not meta.get("video_filename"):
        raise HTTPException(status_code=400, detail="No source video uploaded for this project")

    status = {"status": "running", "step": None, "percent": 0, "error": None}
    meta["analyse"] = status
    storage.write_meta(project_id, meta)

    loop = asyncio.get_running_loop()
    loop.run_in_executor(None, _run_pipeline, project_id)
    return status


@router.get("/{project_id}/analyse/status")
async def analyse_status(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return meta.get("analyse", _idle_status())
