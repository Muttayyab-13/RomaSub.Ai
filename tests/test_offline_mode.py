"""
Tests for the OFFLINE_MODE master switch.

offline_mode forces the whole pipeline local via two computed properties, so a
single flag flips both Whisper and M2M100 for a no-network viva.
"""

from app.config import Settings


def test_offline_mode_forces_local_backends():
    s = Settings(offline_mode=True, whisper_backend="groq", transliteration_backend="modal")
    assert s.effective_whisper_backend == "faster"
    assert s.effective_transliteration_backend == "transformers"


def test_online_mode_passes_backends_through():
    s = Settings(offline_mode=False, whisper_backend="groq", transliteration_backend="modal")
    assert s.effective_whisper_backend == "groq"
    assert s.effective_transliteration_backend == "modal"
