"""Project create/upload/lookup endpoints."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile

from app import storage

router = APIRouter(prefix="/projects", tags=["projects"])


@router.post("")
async def create_project(file: UploadFile = File(...)) -> dict:
    original_filename = file.filename or "upload"
    meta = storage.create_project(original_filename)
    project_id = meta["id"]

    suffix = Path(original_filename).suffix or ".mp4"
    dest = storage.project_dir(project_id) / f"source{suffix}"
    size_bytes = 0
    with dest.open("wb") as out:
        while chunk := await file.read(1024 * 1024):
            size_bytes += len(chunk)
            out.write(chunk)

    meta.update(
        {
            "status": "uploaded",
            "video_filename": dest.name,
            "content_type": file.content_type,
            "size_bytes": size_bytes,
        }
    )
    storage.write_meta(project_id, meta)
    return meta


@router.get("/{project_id}")
async def get_project(project_id: str) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return meta
