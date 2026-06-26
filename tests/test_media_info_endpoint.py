"""
Tests for GET /media/{file_id} endpoint disk-existence guard.

Ensures the info endpoint returns 404 when the file is missing from disk,
aligning it with the stream endpoint's behaviour so MediaService.isMediaAvailable
is reliable.
"""

import os
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import media as media_service

client = TestClient(app)


def test_media_info_404_when_file_missing_on_disk(tmp_path):
    fid = "test-missing-file-id"
    media_service._file_registry[fid] = {
        "file_id": fid,
        "original_filename": "gone.mp4",
        "file_path": str(tmp_path / "does_not_exist.mp4"),  # not created
        "file_size": 1,
        "extension": "mp4",
        "is_video": True,
        "audio_path": None,
        "status": "uploaded",
    }
    try:
        resp = client.get(f"/media/{fid}")
        assert resp.status_code == 404
    finally:
        media_service._file_registry.pop(fid, None)


def test_media_info_200_when_file_present(tmp_path):
    fid = "test-present-file-id"
    real = tmp_path / "present.mp4"
    real.write_bytes(b"data")
    media_service._file_registry[fid] = {
        "file_id": fid,
        "original_filename": "present.mp4",
        "file_path": str(real),
        "file_size": 4,
        "extension": "mp4",
        "is_video": True,
        "audio_path": None,
        "status": "uploaded",
    }
    try:
        resp = client.get(f"/media/{fid}")
        assert resp.status_code == 200
        assert resp.json()["file_id"] == fid
    finally:
        media_service._file_registry.pop(fid, None)


def test_media_info_404_when_unknown():
    resp = client.get("/media/totally-unknown-id")
    assert resp.status_code == 404
