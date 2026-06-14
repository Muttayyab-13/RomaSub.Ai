import pytest

from app.services.video_export import build_output_filename, build_ffmpeg_command


def test_build_output_filename_hardsub():
    assert build_output_filename("clip.mp4", "hardsub") == "clip_roman_subtitled.mp4"


def test_build_output_filename_softsub_strips_only_last_ext():
    assert build_output_filename("My.Holiday.mkv", "softsub") == "My.Holiday_roman_softsubs.mp4"


def test_build_ffmpeg_command_hardsub_burns_subtitles():
    cmd = build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "hardsub")
    assert cmd[0] == "ffmpeg"
    assert "-vf" in cmd
    assert "subtitles=subs.srt" in cmd
    assert "libx264" in cmd
    assert cmd[-1] == "out.mp4"


def test_build_ffmpeg_command_softsub_muxes_track_without_reencode():
    cmd = build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "softsub")
    assert cmd.count("-i") == 2          # video input + srt input
    assert cmd.count("-map") == 2        # map all of input 0, plus the srt
    assert "mov_text" in cmd
    assert "copy" in cmd                 # stream copy = no re-encode
    assert cmd[-1] == "out.mp4"


def test_build_ffmpeg_command_rejects_unknown_mode():
    with pytest.raises(ValueError):
        build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "bogus")
