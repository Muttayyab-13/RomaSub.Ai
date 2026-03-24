"""
Media Router for RomaSub.AI
Handles video/audio file uploads and audio extraction
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import Annotated, Optional
from pydantic import BaseModel
import os
import mimetypes

from app.database import get_db
from app.services import media as media_service
from app.routers.auth import get_current_user
from app.models.user import User
from app.config import settings

router = APIRouter(prefix="/media", tags=["Media"])


class FileUploadResponse(BaseModel):
    """Response schema for file upload"""
    success: bool
    file_id: str
    filename: str
    file_size: int
    file_size_mb: float
    is_video: bool
    message: str


class FileInfoResponse(BaseModel):
    """Response schema for file info"""
    file_id: str
    original_filename: str
    file_size: int
    extension: str
    is_video: bool
    status: str
    has_audio: bool


class AudioExtractionResponse(BaseModel):
    """Response schema for audio extraction"""
    success: bool
    file_id: str
    message: str
    audio_ready: bool


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(
    file: UploadFile = File(..., description="Video or audio file to upload"),
    current_user: Annotated[User, Depends(get_current_user)] = None
):
    """
    Upload a video or audio file for processing.

    Supported formats:
    - Video: MP4, AVI, MKV, MOV, WEBM
    - Audio: MP3, WAV, M4A, FLAC, OGG

    Maximum file size: 500MB

    Returns file_id which is used for subsequent operations.
    """
    # Validate file
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No file provided"
        )

    # Check extension
    if not media_service.is_valid_extension(file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed extensions: {settings.allowed_extensions}"
        )

    # Save file (in-memory tracking)
    success, result, file_info = await media_service.save_upload_file(file)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result
        )

    return FileUploadResponse(
        success=True,
        file_id=result,
        filename=file_info["original_filename"],
        file_size=file_info["file_size"],
        file_size_mb=round(file_info["file_size"] / (1024 * 1024), 2),
        is_video=file_info["is_video"],
        message="File uploaded successfully"
    )


@router.post("/upload/anonymous", response_model=FileUploadResponse)
async def upload_file_anonymous(
    file: UploadFile = File(..., description="Video or audio file to upload")
):
    """
    Upload a video or audio file without authentication (for testing).

    Same as /upload but doesn't require authentication.
    """
    # Validate file
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No file provided"
        )

    # Check extension
    if not media_service.is_valid_extension(file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed extensions: {settings.allowed_extensions}"
        )

    # Save file (in-memory tracking)
    success, result, file_info = await media_service.save_upload_file(file)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result
        )

    return FileUploadResponse(
        success=True,
        file_id=result,
        filename=file_info["original_filename"],
        file_size=file_info["file_size"],
        file_size_mb=round(file_info["file_size"] / (1024 * 1024), 2),
        is_video=file_info["is_video"],
        message="File uploaded successfully"
    )


@router.get("/{file_id}", response_model=FileInfoResponse)
async def get_file_info(file_id: str):
    """
    Get information about an uploaded file.

    - **file_id**: ID returned from upload endpoint
    """
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found"
        )

    return FileInfoResponse(
        file_id=file_info["file_id"],
        original_filename=file_info["original_filename"],
        file_size=file_info["file_size"],
        extension=file_info["extension"],
        is_video=file_info["is_video"],
        status=file_info["status"],
        has_audio=file_info.get("audio_path") is not None
    )


@router.post("/{file_id}/extract-audio", response_model=AudioExtractionResponse)
async def extract_audio(file_id: str):
    """
    Extract audio from a video file.

    For audio files, this just validates the file is ready.
    For video files, extracts audio track as WAV (16kHz, mono).

    - **file_id**: ID of the uploaded file
    """
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found"
        )

    success, result = media_service.extract_audio(file_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result
        )

    return AudioExtractionResponse(
        success=True,
        file_id=file_id,
        message="Audio ready for processing",
        audio_ready=True
    )


@router.delete("/{file_id}")
async def delete_file(file_id: str):
    """
    Delete an uploaded file and its extracted audio.

    - **file_id**: ID of the file to delete
    """
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found"
        )

    success = media_service.cleanup_file(file_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete file"
        )

    return {"success": True, "message": "File deleted successfully"}


@router.get("/{file_id}/stream")
async def stream_file(file_id: str, request: Request):
    """
    Stream a video/audio file with HTTP Range support for seeking.

    Used by the frontend video player to load media files.
    Supports partial content (Range headers) for efficient seeking.
    """
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found"
        )

    file_path = file_info["file_path"]

    if not os.path.exists(file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File no longer exists on disk"
        )

    file_size = os.path.getsize(file_path)
    content_type = mimetypes.guess_type(file_path)[0] or "application/octet-stream"

    # Parse Range header
    range_header = request.headers.get("range")

    if range_header:
        # Parse "bytes=start-end"
        range_spec = range_header.replace("bytes=", "")
        parts = range_spec.split("-")
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if parts[1] else file_size - 1

        # Clamp end
        end = min(end, file_size - 1)
        content_length = end - start + 1

        def iter_range():
            with open(file_path, "rb") as f:
                f.seek(start)
                remaining = content_length
                chunk_size = 1024 * 1024  # 1MB chunks
                while remaining > 0:
                    read_size = min(chunk_size, remaining)
                    data = f.read(read_size)
                    if not data:
                        break
                    remaining -= len(data)
                    yield data

        return StreamingResponse(
            iter_range(),
            status_code=206,
            media_type=content_type,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(content_length),
            },
        )
    else:
        # Full file response
        def iter_file():
            with open(file_path, "rb") as f:
                chunk_size = 1024 * 1024
                while True:
                    data = f.read(chunk_size)
                    if not data:
                        break
                    yield data

        return StreamingResponse(
            iter_file(),
            media_type=content_type,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
            },
        )
