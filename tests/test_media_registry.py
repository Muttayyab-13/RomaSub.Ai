# tests/test_media_registry.py
import importlib


def test_registry_persists_and_reloads(tmp_path, monkeypatch):
    from app.services import media as media_service

    reg_file = tmp_path / "file_registry.json"
    monkeypatch.setattr(media_service, "_FILE_REGISTRY_FILE", str(reg_file))

    media_service._file_registry.clear()
    media_service._file_registry["abc"] = {
        "file_id": "abc",
        "original_filename": "clip.mp4",
        "file_path": "/some/where/abc.mp4",
        "file_size": 123,
        "extension": "mp4",
        "is_video": True,
        "audio_path": None,
        "status": "uploaded",
    }
    media_service._save_registry()

    media_service._file_registry.clear()
    assert media_service.get_file_info("abc") is None
    media_service._load_registry()

    info = media_service.get_file_info("abc")
    assert info is not None
    assert info["original_filename"] == "clip.mp4"
    assert info["is_video"] is True


def test_rehydrate_from_disk_rebuilds_missing_entries(tmp_path, monkeypatch):
    from app.services import media as media_service
    from app.config import settings

    monkeypatch.setattr(media_service, "_FILE_REGISTRY_FILE", str(tmp_path / "reg.json"))
    monkeypatch.setattr(settings, "media_upload_dir", str(tmp_path))
    fid = "11111111-2222-3333-4444-555555555555"
    (tmp_path / f"{fid}.mp4").write_bytes(b"fake video bytes")
    (tmp_path / f"{fid}_audio.wav").write_bytes(b"fake audio")

    media_service._file_registry.clear()
    count = media_service.rehydrate_from_disk()

    assert count == 1
    info = media_service.get_file_info(fid)
    assert info is not None
    assert info["file_path"] == str(tmp_path / f"{fid}.mp4")
    assert info["is_video"] is True
    assert info["audio_path"] == str(tmp_path / f"{fid}_audio.wav")


def test_rehydrate_skips_already_registered(tmp_path, monkeypatch):
    from app.services import media as media_service
    from app.config import settings

    monkeypatch.setattr(media_service, "_FILE_REGISTRY_FILE", str(tmp_path / "reg.json"))
    monkeypatch.setattr(settings, "media_upload_dir", str(tmp_path))
    fid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    (tmp_path / f"{fid}.mp4").write_bytes(b"x")

    media_service._file_registry.clear()
    media_service._file_registry[fid] = {"file_id": fid, "file_path": "kept"}
    count = media_service.rehydrate_from_disk()

    assert count == 0
    assert media_service.get_file_info(fid)["file_path"] == "kept"
