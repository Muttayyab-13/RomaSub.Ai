"""
Tests for the pre-ASR audio enhancement filter builder in
app/services/media.py (build_enhance_filter).

Pure-logic tests — no ffmpeg invocation, no real audio. They pin down the
toggle behaviour and the RNNoise opt-in/fallback contract:

  * disabled            -> None (callers skip -af entirely)
  * enabled             -> conservative highpass/afftdn/dynaudnorm chain
  * RNNoise + model     -> arnndn substituted for afftdn
  * RNNoise, no model   -> transparent fallback to afftdn (never breaks)
"""

from app.services import media


def test_disabled_returns_none(monkeypatch):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", False)
    assert media.build_enhance_filter() is None


def test_enabled_uses_afftdn_chain(monkeypatch):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", True)
    monkeypatch.setattr(media.settings, "audio_enhance_use_rnnoise", False)

    af = media.build_enhance_filter()

    assert af == "highpass=f=80,afftdn=nf=-25,dynaudnorm"


def test_rnnoise_used_when_model_exists(monkeypatch, tmp_path):
    model = tmp_path / "std.rnnn"
    model.write_bytes(b"\x00")  # contents irrelevant; only existence is checked

    monkeypatch.setattr(media.settings, "enable_audio_enhance", True)
    monkeypatch.setattr(media.settings, "audio_enhance_use_rnnoise", True)
    monkeypatch.setattr(media.settings, "audio_rnnoise_model", str(model))

    af = media.build_enhance_filter()

    assert af.startswith("highpass=f=80,arnndn=m='")
    assert str(model) in af
    assert af.endswith(",dynaudnorm")
    assert "afftdn" not in af


def test_rnnoise_falls_back_to_afftdn_when_model_missing(monkeypatch):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", True)
    monkeypatch.setattr(media.settings, "audio_enhance_use_rnnoise", True)
    monkeypatch.setattr(media.settings, "audio_rnnoise_model", "/no/such/model.rnnn")

    af = media.build_enhance_filter()

    # Missing model must never break extraction — fall back to afftdn.
    assert af == "highpass=f=80,afftdn=nf=-25,dynaudnorm"


def test_rnnoise_flag_ignored_when_enhance_disabled(monkeypatch):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", False)
    monkeypatch.setattr(media.settings, "audio_enhance_use_rnnoise", True)
    assert media.build_enhance_filter() is None


# ---------------------------------------------------------------------------
# extract_audio wiring: the -af chain must reach the ffmpeg command when
# enabled (this is what the realtime path inherits by slicing from the output).
# ---------------------------------------------------------------------------

class _FakeCompleted:
    returncode = 0
    stderr = ""


def _register_fake_audio(monkeypatch, tmp_path, is_video):
    """Register a fake input file and stub disk writes; return (file_id, src)."""
    src = tmp_path / ("clip.mp4" if is_video else "clip.wav")
    src.write_bytes(b"\x00\x00")
    fid = "fixture-fid"
    monkeypatch.setitem(media._file_registry, fid, {
        "file_id": fid,
        "original_filename": src.name,
        "file_path": str(src),
        "is_video": is_video,
        "audio_path": None,
        "status": "uploaded",
    })
    monkeypatch.setattr(media, "_save_registry", lambda: None)
    monkeypatch.setattr(media.settings, "media_upload_dir", str(tmp_path))
    return fid, src


def test_extract_audio_injects_filter_when_enabled(monkeypatch, tmp_path):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", True)
    monkeypatch.setattr(media.settings, "audio_enhance_use_rnnoise", False)
    fid, _ = _register_fake_audio(monkeypatch, tmp_path, is_video=True)

    captured = {}

    def fake_run(cmd, capture_output=True, text=True):
        captured["cmd"] = cmd
        # ffmpeg would create the output (last arg); simulate it.
        with open(cmd[-1], "wb") as f:
            f.write(b"\x00" * 16)
        return _FakeCompleted()

    monkeypatch.setattr(media.subprocess, "run", fake_run)

    ok, path = media.extract_audio(fid)

    assert ok is True
    cmd = captured["cmd"]
    assert "-af" in cmd
    assert cmd[cmd.index("-af") + 1] == "highpass=f=80,afftdn=nf=-25,dynaudnorm"
    assert path.endswith("_audio.wav")


def test_extract_audio_passthrough_audio_when_disabled(monkeypatch, tmp_path):
    monkeypatch.setattr(media.settings, "enable_audio_enhance", False)
    fid, src = _register_fake_audio(monkeypatch, tmp_path, is_video=False)

    # No ffmpeg pass at all for plain audio when enhancement is off.
    def boom(*a, **k):
        raise AssertionError("ffmpeg should not run for audio passthrough")

    monkeypatch.setattr(media.subprocess, "run", boom)

    ok, path = media.extract_audio(fid)

    assert ok is True
    assert path == str(src)
