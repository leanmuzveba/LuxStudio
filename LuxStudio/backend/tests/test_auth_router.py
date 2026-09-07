"""Integration coverage for the shared church-passcode gate."""

from app.config import get_settings
from app.main import app
from fastapi.testclient import TestClient


def _client(monkeypatch, passcode: str | None):
    monkeypatch.setattr(get_settings(), "church_passcode", passcode)
    return TestClient(app)


class TestAuthVerify:
    def test_correct_passcode_succeeds(self, monkeypatch):
        client = _client(monkeypatch, "letmein")
        r = client.post("/auth/verify", json={"passcode": "letmein"})
        assert r.status_code == 200
        assert r.json() == {"ok": True}

    def test_wrong_passcode_is_rejected(self, monkeypatch):
        client = _client(monkeypatch, "letmein")
        r = client.post("/auth/verify", json={"passcode": "nope"})
        assert r.status_code == 401

    def test_no_passcode_configured_is_unavailable(self, monkeypatch):
        client = _client(monkeypatch, None)
        r = client.post("/auth/verify", json={"passcode": "anything"})
        assert r.status_code == 503
