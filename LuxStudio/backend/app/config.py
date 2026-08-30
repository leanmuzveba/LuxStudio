"""Environment-driven settings for the LuxStudio backend."""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BACKEND_ROOT = Path(__file__).resolve().parent.parent


class Settings:
    def __init__(self) -> None:
        self.gemini_api_key: str | None = os.environ.get("GEMINI_API_KEY")
        self.storage_dir: Path = Path(
            os.environ.get("STORAGE_DIR", str(BACKEND_ROOT / "storage"))
        ).resolve()
        self.ttl_hours: float = float(os.environ.get("TTL_HOURS", "48"))
        # Dev default: Flutter's `flutter run -d chrome` binds a random localhost
        # port each run, so we allow any localhost origin rather than pinning one.
        # Tighten this before any real deployment.
        allowed = os.environ.get("ALLOWED_ORIGINS")
        self.allowed_origins: list[str] = (
            [o.strip() for o in allowed.split(",") if o.strip()]
            if allowed
            else ["*"]
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
