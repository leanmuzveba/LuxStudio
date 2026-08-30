"""LuxStudio backend: holds the Gemini API key and runs FFmpeg server-side
so neither ever ships in the Flutter Web client."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import storage
from app.config import get_settings
from app.routers import analyse, brand, exports, projects, social

app = FastAPI(title="LuxStudio Backend")

settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(projects.router)
app.include_router(analyse.router)
app.include_router(social.router)
app.include_router(exports.router)
app.include_router(brand.router)


@app.on_event("startup")
async def startup() -> None:
    settings.storage_dir.mkdir(parents=True, exist_ok=True)
    storage.sweep_expired()


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
