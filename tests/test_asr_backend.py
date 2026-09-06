"""
Tests for the pluggable Whisper backend in app/services/asr.py.

Covers:
  * Mapping a Groq verbose_json transcription response to the internal
    {"text", "segments":[{id,start,end,text}]} shape used by the rest of
    the pipeline (SRT export, transliteration).
  * transcribe_chunk() backend dispatch and offline fallback to local Whisper.

These are pure-logic tests — no network and no real model load. The actual
Groq API call and ffmpeg compression are integration glue exercised manually.
"""

import pytest

from app.services import asr


# ---------------------------------------------------------------------------
# _groq_response_to_result: verbose_json -> {text, segments}
# ---------------------------------------------------------------------------

class _Seg:
    """Mimics an SDK response segment object (attribute access)."""
    def __init__(self, id, start, end, text):
        self.id, self.start, self.end, self.text = id, start, end, text


class _Resp:
    """Mimics a Groq verbose_json response object (attribute access)."""
    text = "hello world"
    segments = [
        _Seg(0, 0.0, 1.5, " hello "),
        _Seg(1, 1.5, 3.0, "world "),
    ]


def test_groq_response_mapping_object_style():
    result = asr._groq_response_to_result(_Resp())

    assert result["text"] == "hello world"
    assert result["segments"] == [
        {"id": 0, "start": 0.0, "end": 1.5, "text": "hello"},
        {"id": 1, "start": 1.5, "end": 3.0, "text": "world"},
    ]


def test_groq_response_mapping_dict_style():
    # Some SDK versions / response_format paths yield plain dicts.
    resp = {
        "text": "salam",
        "segments": [{"id": 0, "start": 0.0, "end": 2.0, "text": "salam"}],
    }

    result = asr._groq_response_to_result(resp)

    assert result["text"] == "salam"
    assert result["segments"][0]["text"] == "salam"


def test_groq_response_mapping_empty_segments():
    resp = {"text": "just text", "segments": []}

    result = asr._groq_response_to_result(resp)

    assert result["text"] == "just text"
    assert result["segments"] == []


# ---------------------------------------------------------------------------
# transcribe_chunk: backend dispatch + fallback
# ---------------------------------------------------------------------------

def _stub_local(monkeypatch, marker="local"):
    monkeypatch.setattr(
        asr, "_transcribe_faster_whisper",
        lambda path, language="ur": {"text": marker, "segments": []},
    )


def test_transcribe_chunk_uses_groq_when_configured(monkeypatch):
    monkeypatch.setattr(asr.settings, "whisper_backend", "groq")
    monkeypatch.setattr(asr.settings, "groq_api_key", "test-key")
    monkeypatch.setattr(
        asr, "_transcribe_groq",
        lambda path, language="ur": {"text": "groq", "segments": []},
    )
    _stub_local(monkeypatch)

    assert asr.transcribe_chunk("chunk.wav")["text"] == "groq"


def test_transcribe_chunk_falls_back_to_local_on_groq_error(monkeypatch):
    monkeypatch.setattr(asr.settings, "whisper_backend", "groq")
    monkeypatch.setattr(asr.settings, "groq_api_key", "test-key")

    def boom(path, language="ur"):
        raise RuntimeError("network unreachable")

    monkeypatch.setattr(asr, "_transcribe_groq", boom)
    _stub_local(monkeypatch)

    # Groq blew up -> we must still get a transcription from the local model.
    assert asr.transcribe_chunk("chunk.wav")["text"] == "local"


def test_transcribe_chunk_skips_groq_when_no_key(monkeypatch):
    monkeypatch.setattr(asr.settings, "whisper_backend", "groq")
    monkeypatch.setattr(asr.settings, "groq_api_key", "")
    _stub_local(monkeypatch)

    called = {}
    monkeypatch.setattr(
        asr, "_transcribe_groq",
        lambda path, language="ur": called.setdefault("groq", True),
    )

    result = asr.transcribe_chunk("chunk.wav")

    assert result["text"] == "local"
    assert "groq" not in called  # Groq must not be attempted without a key


def test_transcribe_chunk_local_backend_never_calls_groq(monkeypatch):
    monkeypatch.setattr(asr.settings, "whisper_backend", "faster")
    monkeypatch.setattr(asr.settings, "groq_api_key", "test-key")
    _stub_local(monkeypatch)

    called = {}
    monkeypatch.setattr(
        asr, "_transcribe_groq",
        lambda path, language="ur": called.setdefault("groq", True),
    )

    result = asr.transcribe_chunk("chunk.wav")

    assert result["text"] == "local"
    assert "groq" not in called


def test_transcribe_chunk_offline_mode_forces_local(monkeypatch):
    # OFFLINE_MODE=true must override whisper_backend=groq and never hit network.
    monkeypatch.setattr(asr.settings, "whisper_backend", "groq")
    monkeypatch.setattr(asr.settings, "groq_api_key", "test-key")
    monkeypatch.setattr(asr.settings, "offline_mode", True)
    _stub_local(monkeypatch)

    called = {}
    monkeypatch.setattr(
        asr, "_transcribe_groq",
        lambda path, language="ur": called.setdefault("groq", True),
    )

    result = asr.transcribe_chunk("chunk.wav")

    assert result["text"] == "local"
    assert "groq" not in called
