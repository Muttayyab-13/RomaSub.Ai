import os
import subprocess
import sys


def test_state_dir_defaults_to_app_data():
    # With no STATE_DIR set, runtime state stays alongside the bundled
    # dictionaries in <repo>/app/data (backward-compatible local behaviour).
    from app.config import settings
    from app.services import subtitle as subtitle_service
    from app.services import media as media_service

    assert settings.state_dir.endswith(os.path.join("app", "data"))
    assert subtitle_service._STATE_FILE == os.path.join(
        settings.state_dir, "subtitle_state.json"
    )
    assert media_service._FILE_REGISTRY_FILE == os.path.join(
        settings.state_dir, "file_registry.json"
    )


def test_state_dir_env_redirects_state_files(tmp_path):
    # STATE_DIR must redirect BOTH the subtitle state and the media registry,
    # since they resolve from settings.state_dir at import time.
    state_dir = str(tmp_path / "state")
    code = (
        "from app.config import settings\n"
        "from app.services import subtitle as s\n"
        "from app.services import media as m\n"
        "print(settings.state_dir)\n"
        "print(s._STATE_FILE)\n"
        "print(m._FILE_REGISTRY_FILE)\n"
    )
    env = dict(os.environ)
    env["STATE_DIR"] = state_dir
    result = subprocess.run(
        [sys.executable, "-c", code], env=env, capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    resolved_state_dir, state_file, registry_file = result.stdout.strip().splitlines()

    assert resolved_state_dir == state_dir
    assert state_file == os.path.join(state_dir, "subtitle_state.json")
    assert registry_file == os.path.join(state_dir, "file_registry.json")
    # The override directory is created on startup.
    assert os.path.isdir(state_dir)
