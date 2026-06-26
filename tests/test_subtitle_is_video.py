# tests/test_subtitle_is_video.py
from app.services import media as media_service


def test_is_video_file_true_for_mp4():
    assert media_service.is_video_file("clip.mp4") is True


def test_is_video_file_false_for_wav():
    assert media_service.is_video_file("voice.wav") is False


def test_is_video_file_handles_dotted_names():
    # WhatsApp-style names with multiple dots must still resolve to mp4
    assert media_service.is_video_file("WhatsApp Video 2026-03-29 at 4.32.01 PM.mp4") is True


def test_is_video_file_true_for_uppercase_extension():
    assert media_service.is_video_file("clip.MP4") is True


def test_schema_accepts_is_video_field():
    from app.schemas.subtitle import SubtitleProjectResponse
    resp = SubtitleProjectResponse(
        subtitle_id="s1",
        file_id="f1",
        project_name="p",
        original_filename="clip.mp4",
        segments=[],
        segment_count=0,
        created_at="now",
        updated_at="now",
        is_video=True,
    )
    assert resp.is_video is True


def test_list_projects_includes_is_video():
    from app.services import subtitle as subtitle_service
    sid = "test-sid-isvideo"
    subtitle_service._subtitle_projects[sid] = {
        "subtitle_id": sid,
        "file_id": "fid-x",
        "project_name": "p",
        "original_filename": "clip.mp4",  # legacy dict: no is_video key
        "segments": [],
        "segment_count": 0,
        "file_duration": None,
        "created_at": "now",
        "updated_at": "now",
    }
    try:
        items = subtitle_service.list_all_projects()
        match = next(i for i in items if i["subtitle_id"] == sid)
        assert match["is_video"] is True
    finally:
        subtitle_service._subtitle_projects.pop(sid, None)
