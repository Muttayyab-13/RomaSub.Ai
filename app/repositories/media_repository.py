"""
Media Repository for RomaSub.AI
Data access layer for MediaFile database operations and file storage
"""

import os
import shutil
from pathlib import Path
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session

from app.models.media import MediaFile
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class MediaRepository:
    """Repository for MediaFile database operations and file storage"""

    @staticmethod
    def create_file_record(db: Session, file_data: dict) -> MediaFile:
        """
        Create a new media file record in database.

        Args:
            db: Database session
            file_data: Dictionary with file metadata

        Returns:
            Created MediaFile object
        """
        db_file = MediaFile(**file_data)
        db.add(db_file)
        db.commit()
        db.refresh(db_file)
        logger.info(f"Created file record: {db_file.file_id}")
        return db_file

    @staticmethod
    def get_by_file_id(db: Session, file_id: str) -> Optional[MediaFile]:
        """
        Get media file by file_id.

        Args:
            db: Database session
            file_id: Unique file identifier

        Returns:
            MediaFile object or None
        """
        return db.query(MediaFile).filter(MediaFile.file_id == file_id).first()

    @staticmethod
    def get_by_id(db: Session, id: int) -> Optional[MediaFile]:
        """
        Get media file by database ID.

        Args:
            db: Database session
            id: Database record ID

        Returns:
            MediaFile object or None
        """
        return db.query(MediaFile).filter(MediaFile.id == id).first()

    @staticmethod
    def get_user_files(db: Session, user_id: int, skip: int = 0, limit: int = 100) -> List[MediaFile]:
        """
        Get all files for a specific user.

        Args:
            db: Database session
            user_id: User's database ID
            skip: Number of records to skip
            limit: Maximum number of records to return

        Returns:
            List of MediaFile objects
        """
        return db.query(MediaFile).filter(
            MediaFile.user_id == user_id
        ).order_by(MediaFile.created_at.desc()).offset(skip).limit(limit).all()

    @staticmethod
    def update_file(db: Session, media_file: MediaFile, update_data: dict) -> MediaFile:
        """
        Update media file record.

        Args:
            db: Database session
            media_file: MediaFile object to update
            update_data: Dictionary with fields to update

        Returns:
            Updated MediaFile object
        """
        for key, value in update_data.items():
            if hasattr(media_file, key):
                setattr(media_file, key, value)

        db.commit()
        db.refresh(media_file)
        return media_file

    @staticmethod
    def update_status(db: Session, file_id: str, status: str) -> Optional[MediaFile]:
        """
        Update file processing status.

        Args:
            db: Database session
            file_id: Unique file identifier
            status: New status value

        Returns:
            Updated MediaFile object or None
        """
        media_file = MediaRepository.get_by_file_id(db, file_id)
        if media_file:
            media_file.status = status
            db.commit()
            db.refresh(media_file)
            logger.info(f"Updated file {file_id} status to: {status}")
        return media_file

    @staticmethod
    def update_audio_path(db: Session, file_id: str, audio_path: str) -> Optional[MediaFile]:
        """
        Update audio path after extraction.

        Args:
            db: Database session
            file_id: Unique file identifier
            audio_path: Path to extracted audio file

        Returns:
            Updated MediaFile object or None
        """
        media_file = MediaRepository.get_by_file_id(db, file_id)
        if media_file:
            media_file.audio_path = audio_path
            db.commit()
            db.refresh(media_file)
            logger.info(f"Updated audio path for file {file_id}")
        return media_file

    @staticmethod
    def delete_file_record(db: Session, media_file: MediaFile) -> bool:
        """
        Delete media file record from database.

        Args:
            db: Database session
            media_file: MediaFile object to delete

        Returns:
            True if deleted successfully
        """
        db.delete(media_file)
        db.commit()
        logger.info(f"Deleted file record: {media_file.file_id}")
        return True

    @staticmethod
    def count_user_files(db: Session, user_id: int) -> int:
        """
        Count total files for a user.

        Args:
            db: Database session
            user_id: User's database ID

        Returns:
            Total file count
        """
        return db.query(MediaFile).filter(MediaFile.user_id == user_id).count()

    # File Storage Operations

    @staticmethod
    def ensure_upload_directory() -> str:
        """
        Ensure upload directory exists.

        Returns:
            Path to upload directory
        """
        upload_dir = settings.temp_upload_dir
        os.makedirs(upload_dir, exist_ok=True)
        return upload_dir

    @staticmethod
    def save_file_to_storage(file_path: str, content: bytes) -> Tuple[bool, str]:
        """
        Save file content to storage.

        Args:
            file_path: Full path where file should be saved
            content: File content as bytes

        Returns:
            Tuple of (success, message)
        """
        try:
            # Ensure directory exists
            directory = os.path.dirname(file_path)
            os.makedirs(directory, exist_ok=True)

            # Write file
            with open(file_path, "wb") as f:
                f.write(content)

            logger.info(f"Saved file to storage: {file_path}")
            return True, file_path
        except Exception as e:
            error_msg = f"Failed to save file: {str(e)}"
            logger.error(error_msg)
            return False, error_msg

    @staticmethod
    def delete_file_from_storage(file_path: str) -> bool:
        """
        Delete physical file from storage.

        Args:
            file_path: Path to file to delete

        Returns:
            True if deleted successfully
        """
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.info(f"Deleted file from storage: {file_path}")
                return True
            else:
                logger.warning(f"File not found for deletion: {file_path}")
                return False
        except Exception as e:
            logger.error(f"Failed to delete file {file_path}: {str(e)}")
            return False

    @staticmethod
    def file_exists(file_path: str) -> bool:
        """
        Check if file exists in storage.

        Args:
            file_path: Path to file

        Returns:
            True if file exists
        """
        return os.path.exists(file_path) and os.path.isfile(file_path)

    @staticmethod
    def get_file_size(file_path: str) -> int:
        """
        Get file size in bytes.

        Args:
            file_path: Path to file

        Returns:
            File size in bytes
        """
        if MediaRepository.file_exists(file_path):
            return os.path.getsize(file_path)
        return 0

    @staticmethod
    def delete_file_completely(db: Session, file_id: str) -> Tuple[bool, str]:
        """
        Delete file completely (database record and physical files).

        Args:
            db: Database session
            file_id: Unique file identifier

        Returns:
            Tuple of (success, message)
        """
        media_file = MediaRepository.get_by_file_id(db, file_id)

        if not media_file:
            return False, "File not found"

        # Delete physical files
        files_deleted = []
        if media_file.file_path:
            if MediaRepository.delete_file_from_storage(media_file.file_path):
                files_deleted.append("original file")

        if media_file.audio_path:
            if MediaRepository.delete_file_from_storage(media_file.audio_path):
                files_deleted.append("audio file")

        # Delete database record
        MediaRepository.delete_file_record(db, media_file)

        message = f"Deleted {', '.join(files_deleted) if files_deleted else 'record'}"
        logger.info(f"Completely deleted file {file_id}: {message}")
        return True, message
