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
