"""Integration coverage for export history (V2 Decision #3) — the real
/export flow (with ffmpeg mocked out, same pattern as
test_ffmpeg_client.py's subprocess mocking) recording history, plus the
standalone history list/download/delete endpoints."""

import shutil
from unittest.mock import patch

from app import storage
from app.config import get_settings
from app.main import app
from app.services.ffmpeg_client import FfmpegError
from fastapi.testclient import TestClient


def _client(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "storage_dir", tmp_path)
    return TestClient(app)


def _seed_project_with_clip():
    meta = storage.create_project("sermon.mp4")
    project_id = meta["id"]
    (storage.project_dir(project_id) / "source.mp4").write_bytes(b"source video bytes")
    meta["video_filename"] = "source.mp4"
    clip = {
        "id": "clip1",
        "title": "The Walk of Faith",
        "startMs": 1000,
        "endMs": 5000,
        "viralScore": 90,
        "reason": "strong hook",
        "category": "Strong Hook",
        "includeInExport": True,
    }
    meta["clips"] = [clip]
    storage.write_meta(project_id, meta)
    return project_id, clip


def _fake_export_clip(*, output_path, **kwargs):
    output_path.write_bytes(b"rendered clip bytes")


class TestExportRecordsHistory:
    def test_successful_export_creates_a_persistent_history_entry(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        project_id, clip = _seed_project_with_clip()

        with patch("app.services.ffmpeg_client.export_clip", side_effect=_fake_export_clip):
            r = client.post(
                f"/projects/{project_id}/clips/{clip['id']}/export",
                json={"project_title": "Sunday Sermon"},
            )
        assert r.status_code == 200

        history = client.get("/exports/history").json()
        assert len(history) == 1
        entry = history[0]
        assert entry["status"] == "done"
        assert entry["projectTitle"] == "Sunday Sermon"
        assert entry["clipTitle"] == "The Walk of Faith"
        assert entry["durationMs"] == 4000
        assert entry["sizeBytes"] == len(b"rendered clip bytes")
        assert entry["downloadUrl"] == f"/exports/history/{entry['id']}/download"

        r = client.get(entry["downloadUrl"])
        assert r.status_code == 200
        assert r.content == b"rendered clip bytes"

    def test_export_without_project_title_falls_back_to_original_filename(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        project_id, clip = _seed_project_with_clip()

        with patch("app.services.ffmpeg_client.export_clip", side_effect=_fake_export_clip):
            client.post(f"/projects/{project_id}/clips/{clip['id']}/export", json={})

        history = client.get("/exports/history").json()
        assert history[0]["projectTitle"] == "sermon.mp4"

    def test_failed_export_records_an_error_entry_not_a_file(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        project_id, clip = _seed_project_with_clip()

        with patch("app.services.ffmpeg_client.export_clip", side_effect=FfmpegError("boom")):
            r = client.post(f"/projects/{project_id}/clips/{clip['id']}/export", json={})
        assert r.status_code == 502

        history = client.get("/exports/history").json()
        assert len(history) == 1
        assert history[0]["status"] == "error"
        assert history[0]["error"] == "boom"

        # No download available for a failed export.
        r = client.get(f"/exports/history/{history[0]['id']}/download")
        assert r.status_code == 404

    def test_export_survives_the_source_project_being_deleted(self, tmp_path, monkeypatch):
        """The actual point of Decision #3: history is scoped above
        projects, so it (and the file) outlive the project's own
        storage/<id>/ folder being swept."""
        client = _client(tmp_path, monkeypatch)
        project_id, clip = _seed_project_with_clip()

        with patch("app.services.ffmpeg_client.export_clip", side_effect=_fake_export_clip):
            client.post(f"/projects/{project_id}/clips/{clip['id']}/export", json={})

        shutil.rmtree(storage.project_dir(project_id))

        history = client.get("/exports/history").json()
        r = client.get(history[0]["downloadUrl"])
        assert r.status_code == 200
        assert r.content == b"rendered clip bytes"


class TestExportHistoryCrud:
    def test_delete_removes_entry_and_file(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        project_id, clip = _seed_project_with_clip()

        with patch("app.services.ffmpeg_client.export_clip", side_effect=_fake_export_clip):
            client.post(f"/projects/{project_id}/clips/{clip['id']}/export", json={})

        export_id = client.get("/exports/history").json()[0]["id"]
        r = client.delete(f"/exports/history/{export_id}")
        assert r.status_code == 200
        assert client.get("/exports/history").json() == []
        assert client.get(f"/exports/history/{export_id}/download").status_code == 404

    def test_unknown_id_404s(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.get("/exports/history/nope/download").status_code == 404
        assert client.delete("/exports/history/nope").status_code == 404

    def test_history_is_empty_initially(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.get("/exports/history").json() == []
