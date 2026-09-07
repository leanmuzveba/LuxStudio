"""Single shared church-passcode gate (V2 Decision #1) — one stateless
check endpoint, no user table/sessions/tokens. The Flutter client persists
the fact that a device already passed this check locally (see
lib/services/auth_store.dart); the backend holds no notion of "signed in"
at all."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.config import get_settings

router = APIRouter(prefix="/auth", tags=["auth"])


class PasscodeRequest(BaseModel):
    passcode: str


@router.post("/verify")
async def verify_passcode(body: PasscodeRequest) -> dict:
    configured = get_settings().church_passcode
    if not configured:
        raise HTTPException(status_code=503, detail="No passcode configured on the server")
    if body.passcode != configured:
        raise HTTPException(status_code=401, detail="Incorrect passcode")
    return {"ok": True}
