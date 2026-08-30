"""Server-side FFmpeg calls: probing, silence detection/removal, audio
extraction, and final clip export.

Mirrors lib/services/ffmpeg_service.dart's operations and filter graphs
exactly, just invoked as real `ffmpeg`/`ffprobe` subprocesses instead of
through ffmpeg_kit_flutter_new (which has no Flutter Web equivalent).
Requires ffmpeg/ffprobe on PATH.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from typing import Any

_START_RE = re.compile(r"silence_start:\s*([\d.]+)")
_END_RE = re.compile(r"silence_end:\s*([\d.]+)")


class FfmpegError(RuntimeError):
    """Raised when ffmpeg/ffprobe exits non-zero or produces unreadable output."""


def parse_silence_log(logs: str) -> list[dict[str, Any]]:
    """Parses ffmpeg's `silencedetect` filter log output into
    SilenceRange.toJson()-shaped dicts. Pure and side-effect-free."""
    ranges: list[dict[str, Any]] = []
    pending_start: float | None = None

    for line in logs.split("\n"):
        start_match = _START_RE.search(line)
        if start_match:
            pending_start = float(start_match.group(1))
            continue
        end_match = _END_RE.search(line)
        if end_match and pending_start is not None:
            end = float(end_match.group(1))
            ranges.append(
                {
                    "startMs": round(pending_start * 1000),
                    "endMs": round(end * 1000),
                    "accepted": True,
                }
            )
            pending_start = None
    return ranges


def probe(path: str | Path) -> dict[str, Any]:
    result = subprocess.run(
        [
            "ffprobe",
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise FfmpegError(f"ffprobe could not read {path}: {result.stderr}")

    info = json.loads(result.stdout)
    duration_seconds = float(info.get("format", {}).get("duration", 0) or 0)
    width = height = 0
    for stream in info.get("streams", []):
        if stream.get("codec_type") == "video":
            width = stream.get("width", 0)
            height = stream.get("height", 0)
            break

    return {
        "durationMs": round(duration_seconds * 1000),
        "width": width,
        "height": height,
    }


def _run(args: list[str], error_label: str) -> None:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise FfmpegError(f"{error_label} failed (code {result.returncode}): {result.stderr}")


def detect_silence(
    path: str | Path, *, noise_floor_db: float = -30, min_duration_ms: int = 500
) -> list[dict[str, Any]]:
    """Runs ffmpeg's `silencedetect` audio filter and parses the detected
    silent ranges out of its log output. noise_floor_db is how quiet
    (dBFS) counts as silence; min_duration_ms is the shortest gap worth
    flagging."""
    result = subprocess.run(
        [
            "ffmpeg",
            "-i", str(path),
            "-af", f"silencedetect=noise={noise_floor_db}dB:d={min_duration_ms / 1000}",
            "-f", "null",
            "-",
        ],
        capture_output=True,
        text=True,
    )
    # ffmpeg writes filter logs to stderr regardless of exit code (the null
    # muxer "succeeds" even though there's no real output) — parse stderr
    # either way, matching the Dart original's unconditional log read.
    return parse_silence_log(result.stderr)


def _seconds(ms: int) -> str:
    return f"{ms / 1000:.3f}"


def _between_clause(r: dict[str, Any]) -> str:
    return f"between(t,{_seconds(r['startMs'])},{_seconds(r['endMs'])})"


def remove_ranges(
    *,
    source_path: str | Path,
    output_path: str | Path,
    ranges_to_remove: list[dict[str, Any]],
) -> None:
    """Produces a new file at output_path with ranges_to_remove cut out of
    source_path and the remaining audio/video closed up (no gaps). If
    ranges_to_remove is empty, just copies the source through unchanged."""
    if not ranges_to_remove:
        _run(
            ["ffmpeg", "-y", "-i", str(source_path), "-c", "copy", str(output_path)],
            "ffmpeg copy passthrough",
        )
        return

    expr = "not(" + "+".join(_between_clause(r) for r in ranges_to_remove) + ")"
    _run(
        [
            "ffmpeg", "-y",
            "-i", str(source_path),
            "-vf", f"select={expr},setpts=N/FRAME_RATE/TB",
            "-af", f"aselect={expr},asetpts=N/SR/TB",
            str(output_path),
        ],
        "ffmpeg silence removal",
    )


def extract_audio(source_path: str | Path, output_path: str | Path) -> None:
    """Extracts just the audio track as low-bitrate mono AAC — small enough
    to send to Gemini inline for a typical sermon length."""
    _run(
        [
            "ffmpeg", "-y",
            "-i", str(source_path),
            "-vn", "-ac", "1", "-b:a", "64k",
            str(output_path),
        ],
        "ffmpeg audio extraction",
    )


def _escape_filter_value(value: str) -> str:
    """Escapes a value embedded inside a single-quoted ffmpeg filter option
    (a `subtitles` path or `drawtext` string)."""
    return value.replace("'", "\\'")


def export_clip(
    *,
    source_path: str | Path,
    start_ms: int,
    end_ms: int,
    output_path: str | Path,
    subtitles_path: str | Path | None = None,
    force_style: str | None = None,
    logo_path: str | Path | None = None,
    lower_third_text: str | None = None,
) -> None:
    """Exports the start-end range of source_path as a 1080x1920 vertical
    clip at output_path — the MVP1 primary export target. Optionally burns
    in subtitles_path (an SRT file, timestamps already relative to start)
    styled by force_style (falls back to a plain white/outlined default), a
    logo watermark (bottom-right), and lower_third_text (shown for the
    clip's first 3 seconds)."""
    base = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920"
    if subtitles_path is not None:
        style = force_style or (
            "Fontsize=20,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,"
            "BorderStyle=1,Outline=2"
        )
        base += f",subtitles='{_escape_filter_value(str(subtitles_path))}':force_style='{style}'"
    if lower_third_text is not None:
        base += (
            f",drawtext=text='{_escape_filter_value(lower_third_text)}':"
            "fontcolor=white:fontsize=36:x=(w-text_w)/2:y=h-160:box=1:"
            "boxcolor=black@0.5:boxborderw=12:enable='between(t\\,0\\,3)'"
        )

    args = ["-y", "-ss", _seconds(start_ms), "-to", _seconds(end_ms), "-i", str(source_path)]

    if logo_path is not None:
        args += ["-i", str(logo_path)]
        filter_complex = (
            f"[0:v]{base}[base];[1:v]scale=160:-1[logo];"
            "[base][logo]overlay=W-w-32:H-h-32[outv]"
        )
        args += ["-filter_complex", filter_complex, "-map", "[outv]", "-map", "0:a?"]
    else:
        args += ["-vf", base, "-map", "0:v", "-map", "0:a?"]

    args += ["-c:v", "libx264", "-c:a", "aac", str(output_path)]

    _run(["ffmpeg", *args], "ffmpeg export")
