"""Project create/upload/lookup endpoints."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app import storage
from app.routers.uploads import take_upload
from app.services.ffmpeg_client import probe

router = APIRouter(prefix="/projects", tags=["projects"])


def _finish_project_upload(project_id: str, meta: dict, dest: Path) -> dict:
    meta.update(
        {
            "status": "uploaded",
            "video_filename": dest.name,
            "size_bytes": dest.stat().st_size,
        }
    )
    # Best-effort — ffmpeg/ffprobe may not be installed in every dev
    # environment (raises FileNotFoundError) or may fail to read the file
    # (raises FfmpegError); either way, a missing probe must never fail
    # the upload itself.
    try:
        info = probe(dest)
        meta.update(info)
    except Exception:
        pass

    storage.write_meta(project_id, meta)
    return meta


@router.post("")
async def create_project(file: UploadFile = File(...)) -> dict:
    """Small-file path: one multipart POST, held in memory client-side.
    Fine for a quick test clip; a real 1-2 hour sermon video should go
    through /projects/from-upload (see app/routers/uploads.py's doc for
    why the client needs to avoid a single giant in-memory buffer)."""
    original_filename = file.filename or "upload"
    meta = storage.create_project(original_filename)
    project_id = meta["id"]

    suffix = Path(original_filename).suffix or ".mp4"
    dest = storage.project_dir(project_id) / f"source{suffix}"
    with dest.open("wb") as out:
        while chunk := await file.read(1024 * 1024):
            out.write(chunk)

    return _finish_project_upload(project_id, meta, dest)


@router.post("/from-upload")
async def create_project_from_upload(upload_id: str, filename: str) -> dict:
    """Completes a chunked upload (app/routers/uploads.py) into a new
    project — the large-file counterpart to POST /projects above."""
    meta = storage.create_project(filename)
    project_id = meta["id"]

    suffix = Path(filename).suffix or ".mp4"
    dest = storage.project_dir(project_id) / f"source{suffix}"
    try:
        src = take_upload(upload_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Upload not found") from None
    src.replace(dest)  # same filesystem — a rename, not a copy

    return _finish_project_upload(project_id, meta, dest)


@router.get("/{project_id}")
async def get_project(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return meta


@router.get("/{project_id}/video")
async def get_project_video(project_id: str) -> FileResponse:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")

    filename = meta.get("working_video_filename") or meta.get("video_filename")
    if not filename:
        raise HTTPException(status_code=404, detail="No video uploaded for this project")

    path = storage.project_dir(project_id) / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail="Video file not found")

    return FileResponse(path, media_type="video/mp4", filename=filename)
