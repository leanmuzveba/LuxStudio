"""Global brand logo storage — not project-scoped (branding carries over
to every new sermon imported, per BrandSettings' doc in the Flutter app).
Stored separately from per-project storage/<project_id>/ under
storage/_brand/, outside the TTL sweep (that only walks project dirs)."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.config import get_settings

router = APIRouter(prefix="/brand", tags=["brand"])


def _brand_dir() -> Path:
    d = get_settings().storage_dir / "_brand"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _existing_logo_path() -> Path | None:
    d = _brand_dir()
    matches = sorted(d.glob("logo.*"))
    return matches[0] if matches else None


@router.post("/logo")
async def upload_logo(file: UploadFile = File(...)) -> dict:
    suffix = Path(file.filename or "logo.png").suffix or ".png"

    # Only one logo at a time — clear any previous file (possibly a
    # different extension) before writing the new one.
    for old in _brand_dir().glob("logo.*"):
        old.unlink(missing_ok=True)

    dest = _brand_dir() / f"logo{suffix}"
    dest.write_bytes(await file.read())
    return {"logoUrl": "/brand/logo"}


@router.get("/logo")
async def get_logo() -> FileResponse:
    path = _existing_logo_path()
    if path is None:
        raise HTTPException(status_code=404, detail="No logo set")
    return FileResponse(path)
