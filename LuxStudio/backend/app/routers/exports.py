"""Clip export: crops/scales to 1080x1920 and optionally burns in
captions/branding, mirroring FfmpegService.exportClip. Runs synchronously
(the request blocks until ffmpeg finishes) — clips are short (15-90s), so
no job queue is needed for MVP; revisit if that stops holding."""

from __future__ import annotations

import base64

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app import storage
from app.services import ffmpeg_client
from app.services.ffmpeg_client import FfmpegError

router = APIRouter(prefix="/projects", tags=["exports"])


class ExportRequest(BaseModel):
    subtitles_srt: str | None = None
    force_style: str | None = None
    logo_base64: str | None = None
    lower_third_text: str | None = None


def _find_clip(meta: dict, clip_id: str) -> dict:
    for clip in meta.get("clips", []):
        if clip["id"] == clip_id:
            return clip
    raise HTTPException(status_code=404, detail="Clip not found")


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
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    storage.touch(project_id)
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
