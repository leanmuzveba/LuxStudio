"""Clip export: crops/scales to 1080x1920 and optionally burns in
captions/branding, mirroring FfmpegService.exportClip. Runs synchronously
(the request blocks until ffmpeg finishes) — clips are short (15-90s), so
no job queue is needed for MVP; revisit if that stops holding.

Also records a real export history entry per attempt (V2 Decision #3):
successful exports get their file copied into `storage.exports_dir()`, a
project-independent location the TTL sweep never touches, so "Export
History" (see `history_router` below) survives the source project being
swept — that's the real substance of "scoped above individual projects".
There's no real server-side progress/queue to report beyond "currently
exporting" (a single synchronous call, not multiple concurrent jobs), so
the desktop Exports screen tracks in-flight state client-side instead of
this endpoint faking a job-progress percentage."""

from __future__ import annotations

import base64
import shutil
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app import storage
from app.services import ffmpeg_client
from app.services.ffmpeg_client import FfmpegError

router = APIRouter(prefix="/projects", tags=["exports"])
history_router = APIRouter(prefix="/exports", tags=["exports"])


class ExportRequest(BaseModel):
    subtitles_srt: str | None = None
    force_style: str | None = None
    logo_base64: str | None = None
    lower_third_text: str | None = None
    # The Flutter client's locally-editable VideoProject.title — the
    # backend itself only ever knows original_filename (see
    # storage.create_project), so without this, history entries would show
    # the raw upload filename instead of the user-facing project name.
    project_title: str | None = None


def _find_clip(meta: dict, clip_id: str) -> dict:
    for clip in meta.get("clips", []):
        if clip["id"] == clip_id:
            return clip
    raise HTTPException(status_code=404, detail="Clip not found")


def _append_history(
    *,
    status: str,
    project_id: str,
    project_title: str,
    clip_id: str,
    clip_title: str,
    duration_ms: int,
    history_id: str | None = None,
    size_bytes: int | None = None,
    error: str | None = None,
) -> None:
    history = storage.read_export_history()
    entry: dict[str, Any] = {
        "id": history_id or uuid.uuid4().hex,
        "status": status,
        "projectId": project_id,
        "projectTitle": project_title,
        "clipId": clip_id,
        "clipTitle": clip_title,
        "durationMs": duration_ms,
        "sizeBytes": size_bytes,
        "error": error,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    history.insert(0, entry)
    storage.write_export_history(history)


@router.post("/{project_id}/clips/{clip_id}/export")
async def export_clip(project_id: str, clip_id: str, body: ExportRequest) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    clip = _find_clip(meta, clip_id)

    project_dir = storage.project_dir(project_id)
    source_name = meta.get("working_video_filename") or meta.get("video_filename")
    if not source_name:
        raise HTTPException(status_code=400, detail="No source video uploaded for this project")
    source_path = project_dir / source_name

    exports_dir = project_dir / "exports"
    exports_dir.mkdir(parents=True, exist_ok=True)
    output_path = exports_dir / f"{clip_id}.mp4"

    subtitles_path = None
    if body.subtitles_srt:
        subtitles_path = exports_dir / f"{clip_id}.srt"
        subtitles_path.write_text(body.subtitles_srt, encoding="utf-8")

    logo_path = None
    if body.logo_base64:
        logo_path = exports_dir / f"{clip_id}_logo.png"
        logo_path.write_bytes(base64.b64decode(body.logo_base64))

    clip_title = clip.get("title") or "Untitled Clip"
    duration_ms = int(clip.get("endMs", 0)) - int(clip.get("startMs", 0))
    project_title = body.project_title or meta.get("original_filename") or "Untitled Project"

    try:
        ffmpeg_client.export_clip(
            source_path=source_path,
            start_ms=clip["startMs"],
            end_ms=clip["endMs"],
            output_path=output_path,
            subtitles_path=subtitles_path,
            force_style=body.force_style,
            logo_path=logo_path,
            lower_third_text=body.lower_third_text,
        )
    except FfmpegError as exc:
        _append_history(
            status="error",
            project_id=project_id,
            project_title=project_title,
            clip_id=clip_id,
            clip_title=clip_title,
            duration_ms=duration_ms,
            error=str(exc),
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    storage.touch(project_id)

    history_id = uuid.uuid4().hex
    persistent_dir = storage.exports_dir() / "files"
    persistent_dir.mkdir(parents=True, exist_ok=True)
    persistent_path = persistent_dir / f"{history_id}.mp4"
    shutil.copy2(output_path, persistent_path)

    _append_history(
        status="done",
        project_id=project_id,
        project_title=project_title,
        clip_id=clip_id,
        clip_title=clip_title,
        duration_ms=duration_ms,
        history_id=history_id,
        size_bytes=persistent_path.stat().st_size,
    )

    return {
        "status": "done",
        "downloadUrl": f"/projects/{project_id}/clips/{clip_id}/export/download",
    }


@router.get("/{project_id}/clips/{clip_id}/export/download")
async def download_export(project_id: str, clip_id: str) -> FileResponse:
    output_path = storage.project_dir(project_id) / "exports" / f"{clip_id}.mp4"
    if not output_path.exists():
        raise HTTPException(status_code=404, detail="Export not found")
    return FileResponse(output_path, media_type="video/mp4", filename=f"{clip_id}.mp4")


@history_router.get("/history")
async def list_export_history() -> list[dict]:
    history = storage.read_export_history()
    for entry in history:
        entry["downloadUrl"] = f"/exports/history/{entry['id']}/download"
    return history


@history_router.get("/history/{export_id}/download")
async def download_export_history(export_id: str) -> FileResponse:
    history = storage.read_export_history()
    match = next((e for e in history if e["id"] == export_id), None)
    if match is None or match.get("status") != "done":
        raise HTTPException(status_code=404, detail="Export not found")
    path = storage.exports_dir() / "files" / f"{export_id}.mp4"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Export file not found")
    return FileResponse(path, media_type="video/mp4", filename=f"{match['clipTitle']}.mp4")


@history_router.delete("/history/{export_id}")
async def delete_export_history(export_id: str) -> dict:
    history = storage.read_export_history()
    match = next((e for e in history if e["id"] == export_id), None)
    if match is None:
        raise HTTPException(status_code=404, detail="Export not found")
    (storage.exports_dir() / "files" / f"{export_id}.mp4").unlink(missing_ok=True)
    storage.write_export_history([e for e in history if e["id"] != export_id])
    return {"ok": True}
