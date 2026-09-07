"""Integration coverage for the Media Library asset-library entity
(V2 Decision #2): folders, assets, quota, and reusing an asset to start a
new project."""

from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app


def _client(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "storage_dir", tmp_path)
    return TestClient(app)


class TestFolders:
    def test_no_folders_initially(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.get("/library/folders").json() == []

    def test_create_and_list_folder(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        r = client.post("/library/folders", json={"name": "Sermon B-Roll"})
        assert r.status_code == 200
        folder = r.json()
        assert folder["name"] == "Sermon B-Roll"
        assert folder["id"]

        r = client.get("/library/folders")
        assert [f["name"] for f in r.json()] == ["Sermon B-Roll"]

    def test_blank_folder_name_rejected(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        r = client.post("/library/folders", json={"name": "  "})
        assert r.status_code == 422

    def test_deleting_a_folder_moves_its_assets_to_root_not_deleting_them(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        folder = client.post("/library/folders", json={"name": "Interviews"}).json()
        asset = client.post(
            "/library/assets",
            files={"file": ("clip.mp4", b"fake video bytes", "video/mp4")},
            data={"folder_id": folder["id"]},
        ).json()

        r = client.delete(f"/library/folders/{folder['id']}")
        assert r.status_code == 200
        assert client.get("/library/folders").json() == []

        assets = client.get("/library/assets").json()
        assert len(assets) == 1
        assert assets[0]["id"] == asset["id"]
        assert assets[0]["folder_id"] is None

    def test_deleting_unknown_folder_404s(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.delete("/library/folders/nope").status_code == 404


class TestAssets:
    def test_upload_then_list_and_download(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        r = client.post(
            "/library/assets", files={"file": ("sermon.mp4", b"fake video bytes", "video/mp4")}
        )
        assert r.status_code == 200
        asset = r.json()
        assert asset["filename"] == "sermon.mp4"
        assert asset["size_bytes"] == len(b"fake video bytes")
        assert asset["folder_id"] is None

        r = client.get("/library/assets")
        assert len(r.json()) == 1

        r = client.get(f"/library/assets/{asset['id']}/file")
        assert r.status_code == 200
        assert r.content == b"fake video bytes"

    def test_upload_into_a_folder(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        folder = client.post("/library/folders", json={"name": "Worship Songs"}).json()
        asset = client.post(
            "/library/assets",
            files={"file": ("song.mp4", b"bytes", "video/mp4")},
            data={"folder_id": folder["id"]},
        ).json()
        assert asset["folder_id"] == folder["id"]

    def test_delete_asset_removes_file_and_index_entry(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        asset = client.post(
            "/library/assets", files={"file": ("clip.mp4", b"bytes", "video/mp4")}
        ).json()

        r = client.delete(f"/library/assets/{asset['id']}")
        assert r.status_code == 200
        assert client.get("/library/assets").json() == []
        assert client.get(f"/library/assets/{asset['id']}/file").status_code == 404

    def test_unknown_asset_404s(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.get("/library/assets/nope/file").status_code == 404
        assert client.delete("/library/assets/nope").status_code == 404


class TestUseAssetAsProject:
    def test_use_copies_the_asset_into_a_new_project(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        asset = client.post(
            "/library/assets", files={"file": ("sermon.mp4", b"fake video bytes", "video/mp4")}
        ).json()

        r = client.post(f"/library/assets/{asset['id']}/use")
        assert r.status_code == 200
        project = r.json()
        assert project["id"]
        assert project["original_filename"] == "sermon.mp4"

        r = client.get(f"/projects/{project['id']}/video")
        assert r.status_code == 200
        assert r.content == b"fake video bytes"

        # The library asset itself is untouched — same asset can start
        # another project too (the actual "cross-project reuse").
        assert client.get("/library/assets").json()[0]["id"] == asset["id"]

    def test_use_unknown_asset_404s(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        assert client.post("/library/assets/nope/use").status_code == 404


class TestQuota:
    def test_quota_reflects_total_asset_size(self, tmp_path, monkeypatch):
        client = _client(tmp_path, monkeypatch)
        client.post("/library/assets", files={"file": ("a.mp4", b"12345", "video/mp4")})
        client.post("/library/assets", files={"file": ("b.mp4", b"123", "video/mp4")})

        r = client.get("/library/quota")
        assert r.status_code == 200
        body = r.json()
        assert body["used_bytes"] == 8
        assert body["limit_bytes"] > 0
