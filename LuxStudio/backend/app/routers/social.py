"""Social copy generation — wraps gemini_client.generate_social_copy for a
single clip, mirroring GeminiService.generateSocialCopy's signature."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app import storage
from app.services import gemini_client
from app.services.gemini_client import GeminiError

router = APIRouter(prefix="/projects", tags=["social"])


class TranscriptSegmentIn(BaseModel):
    id: str
    startMs: int
    endMs: int
    text: str
    isSilence: bool = False
    isMarkedForCut: bool = False


class ClipIn(BaseModel):
    id: str
    title: str
    startMs: int
    endMs: int
    viralScore: int
    reason: str
    category: str = ""
    includeInExport: bool = True


class SocialCopyRequest(BaseModel):
    transcript: list[TranscriptSegmentIn]
    clip: ClipIn


@router.post("/{project_id}/social-copy")
async def social_copy(project_id: str, body: SocialCopyRequest) -> dict:
    meta = storage.read_meta(project_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="Project not found")
    storage.touch(project_id)

    try:
        return gemini_client.generate_social_copy(
            [segment.model_dump() for segment in body.transcript],
            body.clip.model_dump(),
        )
    except GeminiError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
