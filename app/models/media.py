"""
Media File Database Model for RomaSub.AI
Stores metadata for uploaded video/audio files
"""

from sqlalchemy import Column, Integer, String, BigInteger, Boolean, Float, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base


class MediaFile(Base):
    """
    Media file metadata model.
    Stores information about uploaded video/audio files.
    """
    __tablename__ = "media_files"

    id = Column(Integer, primary_key=True, index=True)
    file_id = Column(String(36), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)

    # File metadata
    original_filename = Column(String(255), nullable=False)
    file_size = Column(BigInteger, nullable=False)
    extension = Column(String(10), nullable=False)
    is_video = Column(Boolean, nullable=False)

    # File paths
    file_path = Column(String(500), nullable=False)
    audio_path = Column(String(500), nullable=True)

    # Processing status
    status = Column(String(50), default="uploaded")  # uploaded, processing, completed, failed

    # Media properties
    duration_seconds = Column(Float, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationship to user
    user = relationship("User", back_populates="media_files")

    def __repr__(self):
        return f"<MediaFile(file_id={self.file_id}, filename={self.original_filename})>"
