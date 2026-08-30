"""Server-side Gemini calls: transcription, clip suggestions, social copy.

Mirrors lib/services/gemini_service.dart's prompts and JSON contract
exactly, including the field names the Dart models' toJson()/fromJson()
expect (startMs/endMs, viralScore, etc.) — the client's model layer will
be able to deserialize these responses without translation once Phase 5
wires it up. The key difference from the Dart original: the API key is
read from a server-side env var (app.config.get_settings), never from a
client-supplied value, since it must never ship to the Flutter Web bundle.
"""

from __future__ import annotations

import json
import re
import uuid
from typing import Any

from google import genai
from google.genai import types

from app.config import get_settings

_MODEL_NAME = "gemini-2.5-flash"
_FENCE_RE = re.compile(r"^```[a-zA-Z]*\n?")


class GeminiError(RuntimeError):
    """Raised for missing/invalid config or a malformed Gemini response."""


def _strip_fence(raw: str) -> str:
    """Gemini is prompted for raw JSON but sometimes wraps it in a markdown
    code fence anyway — strip that defensively before decoding."""
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = _FENCE_RE.sub("", cleaned, count=1)
        fence_end = cleaned.rfind("```")
        if fence_end != -1:
            cleaned = cleaned[:fence_end]
    return cleaned.strip()


def decode_json_array(raw: str) -> list[Any]:
    decoded = json.loads(_strip_fence(raw))
    if not isinstance(decoded, list):
        raise GeminiError(f"Expected a JSON array from Gemini, got: {decoded!r}")
    return decoded


def decode_json_object(raw: str) -> dict[str, Any]:
    decoded = json.loads(_strip_fence(raw))
    if not isinstance(decoded, dict):
        raise GeminiError(f"Expected a JSON object from Gemini, got: {decoded!r}")
    return decoded


def transcript_segment_from_json(entry: dict[str, Any], index: int) -> dict[str, Any]:
    """Maps one {startSeconds, endSeconds, text} entry into the
    TranscriptSegment.toJson() shape (startMs/endMs, millisecond precision)."""
    return {
        "id": f"t{index}",
        "startMs": round(float(entry["startSeconds"]) * 1000),
        "endMs": round(float(entry["endSeconds"]) * 1000),
        "text": str(entry["text"]).strip(),
        "isSilence": False,
        "isMarkedForCut": False,
    }


def ai_clip_from_json(entry: dict[str, Any], clip_id: str) -> dict[str, Any]:
    """Maps one {title, startSeconds, endSeconds, viralScore, reason,
    category} entry into the AiClip.toJson() shape. Matches the Dart
    original's precision: clip bounds round to the nearest whole SECOND
    (not millisecond, unlike transcript segments)."""
    viral_score = max(0, min(100, round(float(entry["viralScore"]))))
    return {
        "id": clip_id,
        "title": str(entry["title"]).strip(),
        "startMs": round(float(entry["startSeconds"])) * 1000,
        "endMs": round(float(entry["endSeconds"])) * 1000,
        "viralScore": viral_score,
        "reason": str(entry["reason"]).strip(),
        "category": str(entry.get("category") or "").strip(),
        "includeInExport": True,
    }


def social_copy_from_json(entry: dict[str, Any]) -> dict[str, Any]:
    hashtags: list[str] = []
    for tag in entry.get("hashtags") or []:
        cleaned = str(tag).strip()
        if cleaned.startswith("#"):
            cleaned = cleaned[1:]
        if cleaned:
            hashtags.append(cleaned)
    return {
        "title": str(entry.get("title") or "").strip(),
        "summary": str(entry.get("summary") or "").strip(),
        "description": str(entry.get("description") or "").strip(),
        "hashtags": hashtags,
    }


def _client() -> genai.Client:
    settings = get_settings()
    if not settings.gemini_api_key:
        raise GeminiError("GEMINI_API_KEY is not configured on the backend.")
    return genai.Client(api_key=settings.gemini_api_key)


def _generate(
    contents: str | list[Any], *, response_mime_type: str | None = None
) -> Any:
    config = (
        types.GenerateContentConfig(response_mime_type=response_mime_type)
        if response_mime_type
        else None
    )
    return _client().models.generate_content(
        model=_MODEL_NAME, contents=contents, config=config
    )


def _extract_text(response: Any) -> str:
    text = getattr(response, "text", None)
    if not text or not text.strip():
        raise GeminiError("Gemini returned an empty response.")
    return text


_TRANSCRIBE_PROMPT = """Transcribe the spoken audio. Return ONLY a JSON array (no markdown, no
commentary) covering the entire audio in order, back-to-back, with no
gaps or overlaps. Each element must be exactly:
{"startSeconds": number, "endSeconds": number, "text": string}
One element per spoken sentence or phrase. If a stretch of audio has no
speech, skip it (don't emit an element with empty text)."""


def transcribe(audio_bytes: bytes, mime_type: str) -> list[dict[str, Any]]:
    """Transcribes audio_bytes into timestamped TranscriptSegment-shaped dicts."""
    response = _generate(
        [_TRANSCRIBE_PROMPT, types.Part.from_bytes(data=audio_bytes, mime_type=mime_type)],
        response_mime_type="application/json",
    )
    decoded = decode_json_array(_extract_text(response))
    return [
        transcript_segment_from_json(entry, index)
        for index, entry in enumerate(decoded, start=1)
    ]


def suggest_clips(transcript: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Asks Gemini to find complete, engaging short-form clip candidates in
    transcript (silent gaps and lines marked for cut are excluded)."""
    lines = "\n".join(
        f"[{seg['startMs'] // 1000}s-{seg['endMs'] // 1000}s] {seg['text']}"
        for seg in transcript
        if not seg.get("isSilence")
        and not seg.get("isMarkedForCut")
        and str(seg.get("text", "")).strip()
    )

    prompt = f"""Here is a timestamped transcript of a spoken recording:

{lines}

Identify 3 to 6 short-form clip candidates suitable for social media
(15-90 seconds each) — look for strong openings, complete ideas, and
memorable or quotable moments. Clips should not overlap. Start/end times
must be seconds taken from the transcript timestamps above (start of a
line's bracket to end of a line's bracket).

Return ONLY a JSON array (no markdown, no commentary) where each element
is exactly:
{{"title": string, "startSeconds": number, "endSeconds": number, "viralScore": integer 0-100, "reason": string, "category": string}}

"reason" is one short sentence on why this moment works as a standalone
clip. "category" is a short 2-3 word tag naming the type of moment, e.g.
"Strong Hook", "Complete Idea", "Memorable Quote", or "Hot Take". Order
the array by viralScore, highest first."""

    response = _generate(prompt, response_mime_type="application/json")
    decoded = decode_json_array(_extract_text(response))
    return [ai_clip_from_json(entry, uuid.uuid4().hex) for entry in decoded]


def generate_social_copy(
    transcript: list[dict[str, Any]], clip: dict[str, Any]
) -> dict[str, Any]:
    """Writes ready-to-post social copy for clip, grounded in the portion
    of transcript the clip actually covers."""
    clip_start_ms = clip["startMs"]
    clip_end_ms = clip["endMs"]
    clip_text = " ".join(
        seg["text"]
        for seg in transcript
        if not seg.get("isSilence")
        and str(seg.get("text", "")).strip()
        and seg["endMs"] > clip_start_ms
        and seg["startMs"] < clip_end_ms
    )

    prompt = f"""This is the transcript of a short clip titled "{clip['title']}":

{clip_text}

Write ready-to-post social media copy for this clip:
- "title": a short, punchy hook (under 60 characters)
- "summary": one-line description of what the clip is about
- "description": a longer 2-3 sentence caption suitable for a post body
- "hashtags": 3-6 relevant hashtags, without the # symbol

Return ONLY a JSON object (no markdown, no commentary) exactly:
{{"title": string, "summary": string, "description": string, "hashtags": string[]}}"""

    response = _generate(prompt, response_mime_type="application/json")
    decoded = decode_json_object(_extract_text(response))
    return social_copy_from_json(decoded)
