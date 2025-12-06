"""
Configuration settings for RomaSub.AI
Loads environment variables and provides application settings
"""

from pydantic_settings import BaseSettings
from typing import List
import os


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
    
    # MailerSend
    mailersend_api_key: str = ""
    mailersend_sender_email: str = "noreply@romasub.ai"
    mailersend_sender_name: str = "RomaSub.AI"
    
    # Whisper ASR
    whisper_model: str = "small"
    
    # File Upload
    max_file_size_mb: int = 500
    allowed_video_extensions: str = "mp4,avi,mkv,mov,webm"
    allowed_audio_extensions: str = "mp3,wav,m4a,flac,ogg"
    
    # Temp directory for uploaded files
    temp_upload_dir: str = "/tmp/romasub_uploads"
    
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

# Ensure temp directory exists
os.makedirs(settings.temp_upload_dir, exist_ok=True)
