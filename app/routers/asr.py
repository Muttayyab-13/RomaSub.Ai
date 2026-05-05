"""
ASR Router for RomaSub.AI
Handles speech recognition/transcription endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Annotated, List, Optional
from pydantic import BaseModel

from app.database import get_db
from app.services import asr as asr_service
from app.services import media as media_service
from app.routers.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/asr", tags=["ASR - Speech Recognition"])


class TranscriptionSegment(BaseModel):
    """Schema for a transcription segment"""
    id: int
    start: float
    end: float
    text: str


class TranscriptionResponse(BaseModel):
    """Response schema for transcription"""
    success: bool
    file_id: str
    language: str
    text: str
    roman_urdu_text: Optional[str] = None
    segments: List[TranscriptionSegment]
    roman_urdu_segments: Optional[List[dict]] = None
    segment_count: int
    processing_time_seconds: float
    audio_duration_seconds: Optional[float]
    message: str


class TranscriptionRequest(BaseModel):
    """Request schema for transcription"""
    language: str = "ur"  # Default to Urdu
    auto_cleanup: bool = True  # Auto-delete files after transcription (default: True)


class SRTResponse(BaseModel):
    """Response schema for SRT format"""
    file_id: str
    srt_content: str


@router.post("/transcribe/{file_id}", response_model=TranscriptionResponse)
async def transcribe_file(
    file_id: str,
    request: TranscriptionRequest = TranscriptionRequest(),
    current_user: Annotated[User, Depends(get_current_user)] = None
):
    """
    Transcribe an uploaded audio/video file using Whisper.

    This will:
    1. Extract audio from video (if needed)
    2. Run Whisper ASR model
    3. Return transcription with timestamps
    4. Auto-delete temporary files after processing (default)

    - **file_id**: ID of the uploaded file
    - **language**: Language code (default: 'ur' for Urdu)
    - **auto_cleanup**: Auto-delete files after transcription (default: True)

    Supported languages: ur (Urdu), en (English), hi (Hindi), etc.

    Note: Files are automatically deleted after transcription by default.
    Set auto_cleanup=false to keep files for manual cleanup.
    """
    # Check if file exists
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found. Please upload a file first."
        )

    # Run transcription
    success, message, result = asr_service.transcribe_audio(file_id, request.language, request.auto_cleanup)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=message
        )
    
    return TranscriptionResponse(
        success=True,
        file_id=file_id,
        language=result["language"],
        text=result["text"],
        roman_urdu_text=result.get("roman_urdu_text"),
        segments=[TranscriptionSegment(**seg) for seg in result["segments"]],
        roman_urdu_segments=result.get("roman_urdu_segments"),
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        audio_duration_seconds=result.get("audio_duration_seconds"),
        message="Transcription completed successfully"
    )


@router.post("/transcribe/{file_id}/anonymous", response_model=TranscriptionResponse)
async def transcribe_file_anonymous(
    file_id: str,
    request: TranscriptionRequest = TranscriptionRequest()
):
    """
    Transcribe an uploaded file without authentication (for testing).

    Same as /transcribe/{file_id} but doesn't require authentication.
    """
    # Check if file exists
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found. Please upload a file first."
        )

    # Run transcription
    success, message, result = asr_service.transcribe_audio(file_id, request.language, request.auto_cleanup)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=message
        )
    
    return TranscriptionResponse(
        success=True,
        file_id=file_id,
        language=result["language"],
        text=result["text"],
        roman_urdu_text=result.get("roman_urdu_text"),
        segments=[TranscriptionSegment(**seg) for seg in result["segments"]],
        roman_urdu_segments=result.get("roman_urdu_segments"),
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        audio_duration_seconds=result.get("audio_duration_seconds"),
        message="Transcription completed successfully"
    )


@router.get("/result/{file_id}", response_model=TranscriptionResponse)
async def get_transcription_result(file_id: str):
    """
    Get existing transcription result.
    
    Use this to retrieve a previously generated transcription.
    
    - **file_id**: ID of the file that was transcribed
    """
    result = asr_service.get_transcription_result(file_id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transcription not found. Please transcribe the file first."
        )
    
    return TranscriptionResponse(
        success=True,
        file_id=file_id,
        language=result["language"],
        text=result["text"],
        roman_urdu_text=result.get("roman_urdu_text"),
        segments=[TranscriptionSegment(**seg) for seg in result["segments"]],
        roman_urdu_segments=result.get("roman_urdu_segments"),
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        audio_duration_seconds=result.get("audio_duration_seconds"),
        message="Transcription retrieved successfully"
    )


@router.get("/result/{file_id}/srt", response_model=SRTResponse)
async def get_transcription_as_srt(file_id: str):
    """
    Get transcription result in SRT subtitle format.
    
    - **file_id**: ID of the file that was transcribed
    """
    result = asr_service.get_transcription_result(file_id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transcription not found. Please transcribe the file first."
        )
    
    srt_content = asr_service.format_as_srt(result["segments"])

    # Record this download so it appears on the Recent Exports page.
    try:
        from app.services import subtitle as subtitle_service
        original = result.get("original_filename") or f"file_{file_id}"
        base = original.rsplit(".", 1)[0]
        subtitle_service.record_export(
            subtitle_id=None,
            fmt="srt",
            filename=f"{base}_urdu.srt",
            file_id=file_id,
        )
    except Exception:
        pass

    return SRTResponse(
        file_id=file_id,
        srt_content=srt_content
    )


@router.get("/languages")
async def get_supported_languages():
    """
    Get list of supported languages for transcription.
    
    Returns common language codes supported by Whisper.
    """
    return {
        "supported_languages": [
            {"code": "ur", "name": "Urdu", "native": "اردو"},
            {"code": "en", "name": "English", "native": "English"},
            {"code": "hi", "name": "Hindi", "native": "हिन्दी"},
            {"code": "ar", "name": "Arabic", "native": "العربية"},
            {"code": "fa", "name": "Persian", "native": "فارسی"},
            {"code": "pa", "name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
            {"code": "bn", "name": "Bengali", "native": "বাংলা"},
        ],
        "default": "ur",
        "note": "Whisper supports 99+ languages. These are commonly used for this application."
    }
