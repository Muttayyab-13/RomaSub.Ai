"""
Configuration settings for RomaSub.AI
Loads environment variables and provides application settings
"""

from pydantic_settings import BaseSettings
from typing import List
import os

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Database
    database_url: str = "postgresql://postgres:postgres@localhost:5432/romasub_ai"
    
    # JWT Authentication
    secret_key: str = "your-super-secret-key-change-this"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440  # 24 hours
    
    # Google OAuth
    google_client_id: str = ""
    google_client_secret: str = ""
    
    # Brevo (transactional email — see app/services/email.py)
    brevo_api_key: str = ""
    brevo_sender_email: str = "noreply@romasub.me"
    brevo_sender_name: str = "RomaSub.AI"
    
    # Whisper ASR
    # Backend selects where Whisper runs:
    #   "groq"   — Groq-hosted Whisper (large-v3-turbo). Fastest; needs
    #              groq_api_key. Falls back to local faster-whisper on any
    #              error (no network / no credits / file too large).
    #   "faster" — local faster-whisper (CTranslate2, int8). Offline, low RAM.
    #   "openai" — local openai-whisper (original behaviour).
    whisper_backend: str = "groq"
    # Local model name for the "faster"/"openai" backends (and the groq fallback).
    whisper_model: str = "medium"
    # faster-whisper CPU quantization: "int8" (fast, low RAM), "int8_float16", "float32".
    whisper_compute_type: str = "int8"

    # Groq hosted Whisper (OpenAI-compatible Audio API). Key: console.groq.com/keys
    groq_api_key: str = ""
    groq_model: str = "whisper-large-v3-turbo"

    # Transliteration (M2M100)
    m2m100_model_path: str = "models/m2m100_ur_to_rur"
    m2m100_tokenizer_path: str = "models/m2m100_tokenizer"
    transliteration_device: str = "auto"

    # Urdu pre-processing (normalization always on; diacritization stub for future)
    enable_diacritics: bool = False

    # Loanword/names dictionary substitution layer (loanword_processor.process_batch).
    # When True, Urdu words found in app/data/loanword_dict.json + names_dict.json
    # are replaced with their English value BEFORE the model runs and stitched
    # back at the end. When False, the model handles all words directly.
    # Disable when the dictionary content is unverified — see
    # scripts/audit_loanword_dict.py and scripts/loanword_dict_audit.md.
    enable_loanword_dict: bool = True

    # Claude refinement layer (post-m2m100 polish)
    enable_llm_refine: bool = True
    claude_refine_model: str = "claude-haiku-4-5"
    anthropic_api_key: str = ""
    
    # File Upload
    max_file_size_mb: int = 2048
    allowed_video_extensions: str = "mp4,avi,mkv,mov,webm"
    allowed_audio_extensions: str = "mp3,wav,m4a,flac,ogg"
    
    # Durable directory for uploaded media files (survives restarts/reboots).
    # Was previously /tmp/romasub_uploads, which is wiped on reboot and left
    # recents projects pointing at missing files.
    media_upload_dir: str = os.path.join(_PROJECT_ROOT, "uploads", "media")

    # Directory for durable runtime JSON state (subtitle_state.json +
    # file_registry.json). Defaults to app/data alongside the bundled
    # loanword/names dictionaries for local dev. In containers point this at a
    # mounted volume (e.g. STATE_DIR=/app/var/state) so state survives redeploys
    # WITHOUT a volume shadowing the image-baked dictionaries.
    state_dir: str = os.path.join(_PROJECT_ROOT, "app", "data")

    @property
    def allowed_extensions(self) -> List[str]:
        """Get all allowed file extensions"""
        video_ext = self.allowed_video_extensions.split(",")
        audio_ext = self.allowed_audio_extensions.split(",")
        return video_ext + audio_ext
    
    @property
    def max_file_size_bytes(self) -> int:
        """Get max file size in bytes"""
        return self.max_file_size_mb * 1024 * 1024
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


# Create global settings instance
settings = Settings()

# Ensure media upload + runtime state directories exist
os.makedirs(settings.media_upload_dir, exist_ok=True)
os.makedirs(settings.state_dir, exist_ok=True)
