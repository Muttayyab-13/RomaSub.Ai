"""
Tests for the pluggable M2M100 backend in app/services/transliteration.py.

Covers dispatch between the Modal cloud backend and the local transformers
backend, the offline master switch, and the Modal HTTP request/response shape.
Pure-logic tests — no network and no real model load.
"""

from app.services import transliteration as tr


def _stub_transformers(monkeypatch, marker="transformers"):
    monkeypatch.setattr(
        tr, "_m2m100_batch_transformers",
        lambda texts, batch_size=8: [marker] * len(texts),
    )


# ---------------------------------------------------------------------------
# Dispatch + fallback
# ---------------------------------------------------------------------------

def test_dispatch_uses_modal_when_configured(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(
        tr, "_m2m100_batch_modal",
        lambda texts, batch_size=8: ["modal"] * len(texts),
    )
    _stub_transformers(monkeypatch)

    assert tr._m2m100_batch(["a", "b"]) == ["modal", "modal"]


def test_dispatch_falls_back_to_local_on_modal_error(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")

    def boom(texts, batch_size=8):
        raise RuntimeError("modal down")

    monkeypatch.setattr(tr, "_m2m100_batch_modal", boom)
    _stub_transformers(monkeypatch)

    assert tr._m2m100_batch(["a"]) == ["transformers"]


def test_dispatch_skips_modal_when_no_url(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "")
    _stub_transformers(monkeypatch)

    called = {}
    monkeypatch.setattr(
        tr, "_m2m100_batch_modal",
        lambda texts, batch_size=8: called.setdefault("modal", True),
    )

    assert tr._m2m100_batch(["a"]) == ["transformers"]
    assert "modal" not in called


def test_dispatch_offline_forces_local(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(tr.settings, "offline_mode", True)  # viva switch
    _stub_transformers(monkeypatch)

    called = {}
    monkeypatch.setattr(
        tr, "_m2m100_batch_modal",
        lambda texts, batch_size=8: called.setdefault("modal", True),
    )

    assert tr._m2m100_batch(["a"]) == ["transformers"]
    assert "modal" not in called


# ---------------------------------------------------------------------------
# Modal HTTP client shape
# ---------------------------------------------------------------------------

def test_modal_client_posts_texts_and_reads_transliterations(monkeypatch):
    captured = {}

    class FakeResp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"transliterations": ["x", "y"]}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured["url"], captured["headers"], captured["json"] = url, headers, json
        return FakeResp()

    import requests
    monkeypatch.setattr(requests, "post", fake_post)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(tr.settings, "modal_auth_token", "secret")

    out = tr._m2m100_batch_modal(["a", "b"])

    assert out == ["x", "y"]
    assert captured["url"] == "https://x.modal.run"
    assert captured["headers"]["Authorization"] == "Bearer secret"
    assert captured["json"] == {"texts": ["a", "b"]}
