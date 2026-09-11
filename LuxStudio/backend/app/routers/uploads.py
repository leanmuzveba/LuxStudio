"""Generic chunked upload endpoint.

A 1-2 hour sermon video is easily several GB. Uploading it as one
multipart POST means the Flutter Web client has to materialize the whole
thing as a single in-memory buffer first (file_picker's readAsBytes()) —
for a file that large, that alone can exceed what the browser tab's
process is allowed to hold and crash it, independent of how the request
itself is encoded. The fix is chunked upload: the client reads and PUTs
the file in small fixed-size pieces instead.

Two-phase, since the browser doesn't know the final resource (a project or
a library asset) until the bytes are actually up:
  1. POST /uploads                     -> {upload_id}   (reserves a temp file)
  2. PUT  /uploads/{id}/chunk?offset=N  (raw chunk body) -> {received}
  3. The caller (projects.py / library.py) then calls take_upload(upload_id)
     to move the assembled temp file into its final location — a rename,
     not a copy, since it's on the same filesystem.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request

from app import storage

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("")
async def start_upload() -> dict:
    upload_id = uuid.uuid4().hex
    (storage.uploads_dir() / upload_id).touch()
    return {"upload_id": upload_id}


@router.put("/{upload_id}/chunk")
async def upload_chunk(upload_id: str, offset: int, request: Request) -> dict:
    path = storage.uploads_dir() / upload_id
    if not path.exists():
        raise HTTPException(status_code=404, detail="Upload not found")

    current_size = path.stat().st_size
    if offset != current_size:
        raise HTTPException(
            status_code=409, detail=f"Expected offset {current_size}, got {offset}"
        )

    body = await request.body()
    with path.open("ab") as f:
        f.write(body)
    return {"received": current_size + len(body)}


def take_upload(upload_id: str) -> Path:
    """Returns the assembled upload's path for the caller to move/rename
    into its final location. Raises FileNotFoundError if unknown."""
    path = storage.uploads_dir() / upload_id
    if not path.exists():
        raise FileNotFoundError(upload_id)
    return path
