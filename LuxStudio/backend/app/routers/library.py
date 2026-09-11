"""Media Library — a real backend asset-library entity (V2 Decision #2):
folders + video assets that live independently of any one project, so the
same uploaded video can be reused to start multiple projects.

Deliberately NOT a full rewrite of how an in-flight project owns its
working copy — the analyse/export pipeline built across Phases 0-26 still
reads/writes a project's own storage/<id>/ folder. `/library/assets/{id}/use`
bridges the two by copying a library asset's bytes into a fresh project;
that's what "cross-project reuse" buys here without touching the render
pipeline. A deeper migration to assets-by-reference (no per-project copy at
all) is a bigger, riskier change left for a future decision if needed.
"""

from __future__ import annotations

import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app import storage
from app.config import get_settings
from app.routers.uploads import take_upload
from app.services.ffmpeg_client import probe

router = APIRouter(prefix="/library", tags=["library"])

_FOLDERS = "folders"
_ASSETS = "assets"


def _assets_dir() -> Path:
    d = storage.library_dir() / "assets"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _find_asset(asset_id: str) -> dict[str, Any]:
    assets = storage.read_library_index(_ASSETS)
    match = next((a for a in assets if a["id"] == asset_id), None)
    if match is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return match


class FolderCreate(BaseModel):
    name: str


@router.get("/folders")
async def list_folders() -> list[dict]:
    return storage.read_library_index(_FOLDERS)


@router.post("/folders")
async def create_folder(body: FolderCreate) -> dict:
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Folder name is required")
    folders = storage.read_library_index(_FOLDERS)
    folder = {"id": uuid.uuid4().hex, "name": name}
    folders.append(folder)
    storage.write_library_index(_FOLDERS, folders)
    return folder


@router.delete("/folders/{folder_id}")
async def delete_folder(folder_id: str) -> dict:
    folders = storage.read_library_index(_FOLDERS)
    remaining = [f for f in folders if f["id"] != folder_id]
    if len(remaining) == len(folders):
        raise HTTPException(status_code=404, detail="Folder not found")
    storage.write_library_index(_FOLDERS, remaining)

    # Assets in a deleted folder move to root rather than being deleted —
    # non-destructive by default.
    assets = storage.read_library_index(_ASSETS)
    for asset in assets:
        if asset.get("folder_id") == folder_id:
            asset["folder_id"] = None
    storage.write_library_index(_ASSETS, assets)
    return {"ok": True}


@router.get("/assets")
async def list_assets() -> list[dict]:
    return storage.read_library_index(_ASSETS)


def _finish_asset_upload(dest: Path, original_filename: str, folder_id: str | None) -> dict:
    asset: dict[str, Any] = {
        "id": dest.stem,
        "filename": original_filename,
        "stored_filename": dest.name,
        "folder_id": folder_id,
        "content_type": None,
        "size_bytes": dest.stat().st_size,
    }
    # Best-effort, same as /projects — a missing ffprobe must never fail
    # the upload itself.
    try:
        asset.update(probe(dest))
    except Exception:
        pass

    assets = storage.read_library_index(_ASSETS)
    assets.append(asset)
    storage.write_library_index(_ASSETS, assets)
    return asset


@router.post("/assets")
async def upload_asset(file: UploadFile = File(...), folder_id: str | None = Form(None)) -> dict:
    """Small-file path — see projects.py's create_project for why a large
    video should go through /assets/from-upload instead."""
    asset_id = uuid.uuid4().hex
    original_filename = file.filename or "asset"
    suffix = Path(original_filename).suffix or ".mp4"
    dest = _assets_dir() / f"{asset_id}{suffix}"

    with dest.open("wb") as out:
        while chunk := await file.read(1024 * 1024):
            out.write(chunk)

    return _finish_asset_upload(dest, original_filename, folder_id)


@router.post("/assets/from-upload")
async def create_asset_from_upload(
    upload_id: str, filename: str, folder_id: str | None = None
) -> dict:
    """Completes a chunked upload (app/routers/uploads.py) into a new
    library asset."""
    asset_id = uuid.uuid4().hex
    suffix = Path(filename).suffix or ".mp4"
    dest = _assets_dir() / f"{asset_id}{suffix}"
    try:
        src = take_upload(upload_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Upload not found") from None
    src.replace(dest)  # same filesystem — a rename, not a copy

    return _finish_asset_upload(dest, filename, folder_id)


@router.delete("/assets/{asset_id}")
async def delete_asset(asset_id: str) -> dict:
    match = _find_asset(asset_id)
    (_assets_dir() / match["stored_filename"]).unlink(missing_ok=True)
    assets = storage.read_library_index(_ASSETS)
    storage.write_library_index(_ASSETS, [a for a in assets if a["id"] != asset_id])
    return {"ok": True}


@router.get("/assets/{asset_id}/file")
async def get_asset_file(asset_id: str) -> FileResponse:
    match = _find_asset(asset_id)
    path = _assets_dir() / match["stored_filename"]
    if not path.exists():
        raise HTTPException(status_code=404, detail="Asset file not found")
    return FileResponse(path, media_type=match.get("content_type") or "video/mp4", filename=match["filename"])


@router.post("/assets/{asset_id}/use")
async def use_asset_as_project(asset_id: str) -> dict:
    """Starts a new project from a library asset by copying its video into
    a fresh project folder — see module docstring."""
    match = _find_asset(asset_id)
    src = _assets_dir() / match["stored_filename"]
    if not src.exists():
        raise HTTPException(status_code=404, detail="Asset file not found")

    meta = storage.create_project(match["filename"])
    project_id = meta["id"]
    suffix = Path(match["stored_filename"]).suffix or ".mp4"
    dest = storage.project_dir(project_id) / f"source{suffix}"
    dest.write_bytes(src.read_bytes())

    meta.update(
        {
            "status": "uploaded",
            "video_filename": dest.name,
            "content_type": match.get("content_type"),
            "size_bytes": match.get("size_bytes"),
        }
    )
    try:
        meta.update(probe(dest))
    except Exception:
        pass
    storage.write_meta(project_id, meta)
    return meta


@router.get("/quota")
async def get_quota() -> dict:
    assets = storage.read_library_index(_ASSETS)
    used = sum(int(a.get("size_bytes") or 0) for a in assets)
    return {"used_bytes": used, "limit_bytes": get_settings().library_quota_bytes}
