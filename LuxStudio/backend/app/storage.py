"""Disk-backed project storage: one folder per project, a JSON sidecar for
metadata, and a TTL sweep that deletes stale projects. No database — this is
the "lighter proxy" storage model the pivot plan calls for."""

from __future__ import annotations

import json
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from app.config import get_settings

META_FILENAME = "meta.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def project_dir(project_id: str) -> Path:
    return get_settings().storage_dir / project_id


def meta_path(project_id: str) -> Path:
    return project_dir(project_id) / META_FILENAME


def read_meta(project_id: str) -> dict[str, Any] | None:
    path = meta_path(project_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write_meta(project_id: str, data: dict[str, Any]) -> None:
    data["updated_at"] = _now_iso()
    meta_path(project_id).write_text(
        json.dumps(data, indent=2), encoding="utf-8"
    )


def create_project(original_filename: str) -> dict[str, Any]:
    project_id = uuid.uuid4().hex
    project_dir(project_id).mkdir(parents=True, exist_ok=True)
    now = _now_iso()
    meta: dict[str, Any] = {
        "id": project_id,
        "created_at": now,
        "updated_at": now,
        "original_filename": original_filename,
        "status": "created",
    }
    write_meta(project_id, meta)
    return meta


def touch(project_id: str) -> None:
    meta = read_meta(project_id)
    if meta is not None:
        write_meta(project_id, meta)


def sweep_expired(ttl_hours: float | None = None) -> list[str]:
    """Delete project folders whose meta.json hasn't been touched within the
    TTL window. Returns the list of removed project ids."""
    settings = get_settings()
    ttl = ttl_hours if ttl_hours is not None else settings.ttl_hours
    storage_dir = settings.storage_dir
    if not storage_dir.exists():
        return []

    removed: list[str] = []
    now = datetime.now(timezone.utc)
    for child in storage_dir.iterdir():
        if not child.is_dir():
            continue
        meta = read_meta(child.name)
        if meta is None:
            continue
        try:
            updated_at = datetime.fromisoformat(meta["updated_at"])
        except (KeyError, ValueError):
            continue
        age_hours = (now - updated_at).total_seconds() / 3600
        if age_hours > ttl:
            shutil.rmtree(child, ignore_errors=True)
            removed.append(child.name)
    return removed
