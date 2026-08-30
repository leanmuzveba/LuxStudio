"""Integration coverage for the global brand logo endpoints."""

from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app


def _client(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "storage_dir", tmp_path)
    return TestClient(app)


class TestBrandLogo:
    def test_get_logo_404_when_none_set(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        r = client.get("/brand/logo")
        assert r.status_code == 404

    def test_upload_then_get_logo(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        r = client.post(
            "/brand/logo", files={"file": ("logo.png", b"fake png bytes", "image/png")}
        )
        assert r.status_code == 200
        assert r.json() == {"logoUrl": "/brand/logo"}

        r = client.get("/brand/logo")
        assert r.status_code == 200
        assert r.content == b"fake png bytes"

    def test_uploading_again_replaces_the_previous_logo(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        client.post("/brand/logo", files={"file": ("logo.png", b"first", "image/png")})
        client.post("/brand/logo", files={"file": ("logo.jpg", b"second", "image/jpeg")})

        r = client.get("/brand/logo")
        assert r.status_code == 200
        assert r.content == b"second"

        # Only one logo file should remain on disk (no leftover .png).
        brand_dir = tmp_path / "_brand"
        assert sorted(p.name for p in brand_dir.glob("logo.*")) == ["logo.jpg"]
