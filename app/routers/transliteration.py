"""
Transliteration Router for RomaSub.AI
Handles Urdu to Roman Urdu transliteration endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Annotated, List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.services import transliteration as transliteration_service
from app.routers.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/transliterate", tags=["Transliteration - Urdu to Roman Urdu"])


# ============================================================================
# Pydantic Schemas
# ============================================================================

class TransliterationTextRequest(BaseModel):
    """Request schema for standalone text transliteration"""
    text: str


class TransliterationTextResponse(BaseModel):
    """Response schema for standalone text transliteration"""
    success: bool
    urdu_text: str
    roman_urdu_text: str
    processing_time_seconds: float


class TransliteratedSegment(BaseModel):
    """Schema for a transliterated subtitle segment"""
    id: int
    start: float
    end: float
    urdu_text: str
    roman_urdu_text: str


class TransliterationResponse(BaseModel):
    """Response schema for file-based transliteration"""
    success: bool
    file_id: str
    urdu_text: str
    roman_urdu_text: str
    segments: List[TransliteratedSegment]
    segment_count: int
    processing_time_seconds: float
    message: str


class SRTResponse(BaseModel):
    """Response schema for SRT format"""
    file_id: str
    srt_content: str


# ============================================================================
# Endpoints
# ============================================================================

@router.post("/text", response_model=TransliterationTextResponse)
async def transliterate_text(request: TransliterationTextRequest):
    """
    Transliterate raw Urdu text to Roman Urdu.

    This is a standalone endpoint that doesn't require a file upload.
    Useful for testing the transliteration model or converting individual text.

    - **text**: Urdu text string to transliterate
    """
    if not request.text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Text cannot be empty"
        )

    try:
        start_time = datetime.now()
        roman_urdu = transliteration_service.transliterate_text(request.text)
        processing_time = (datetime.now() - start_time).total_seconds()

        return TransliterationTextResponse(
            success=True,
            urdu_text=request.text,
            roman_urdu_text=roman_urdu,
            processing_time_seconds=processing_time
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Transliteration failed: {str(e)}"
        )


@router.post("/{file_id}", response_model=TransliterationResponse)
async def transliterate_file(
    file_id: str,
    current_user: Annotated[User, Depends(get_current_user)] = None
):
    """
    Transliterate all segments from an existing ASR transcription.

    The file must have been transcribed first using the ASR endpoint.
    This will transliterate each Urdu text segment to Roman Urdu.

    - **file_id**: ID of the file that was transcribed
    """
    success, message, result = transliteration_service.transliterate_transcription(file_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND if "not found" in message.lower() else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=message
        )

    return TransliterationResponse(
        success=True,
        file_id=file_id,
        urdu_text=result["urdu_text"],
        roman_urdu_text=result["roman_urdu_text"],
        segments=[TransliteratedSegment(**seg) for seg in result["segments"]],
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        message="Transliteration completed successfully"
    )


@router.post("/{file_id}/anonymous", response_model=TransliterationResponse)
async def transliterate_file_anonymous(file_id: str):
    """
    Transliterate all segments without authentication (for testing).

    Same as /{file_id} but doesn't require authentication.
    """
    success, message, result = transliteration_service.transliterate_transcription(file_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND if "not found" in message.lower() else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=message
        )

    return TransliterationResponse(
        success=True,
        file_id=file_id,
        urdu_text=result["urdu_text"],
        roman_urdu_text=result["roman_urdu_text"],
        segments=[TransliteratedSegment(**seg) for seg in result["segments"]],
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        message="Transliteration completed successfully"
    )


@router.get("/result/{file_id}", response_model=TransliterationResponse)
async def get_transliteration_result(file_id: str):
    """
    Get existing transliteration result.

    Use this to retrieve a previously generated transliteration.

    - **file_id**: ID of the file that was transliterated
    """
    result = transliteration_service.get_transliteration_result(file_id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transliteration not found. Please transliterate the file first."
        )

    return TransliterationResponse(
        success=True,
        file_id=file_id,
        urdu_text=result["urdu_text"],
        roman_urdu_text=result["roman_urdu_text"],
        segments=[TransliteratedSegment(**seg) for seg in result["segments"]],
        segment_count=result["segment_count"],
        processing_time_seconds=result["processing_time_seconds"],
        message="Transliteration retrieved successfully"
    )


@router.get("/result/{file_id}/srt", response_model=SRTResponse)
async def get_transliteration_as_srt(file_id: str):
    """
    Get transliteration result in SRT subtitle format (Roman Urdu).

    - **file_id**: ID of the file that was transliterated
    """
    result = transliteration_service.get_transliteration_result(file_id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transliteration not found. Please transliterate the file first."
        )

    srt_content = transliteration_service.format_roman_urdu_srt(result["segments"])

    # Record this Roman-Urdu SRT download in the Recent Exports list.
    try:
        from app.services import subtitle as subtitle_service
        from app.services import asr as asr_service
        asr_result = asr_service.get_transcription_result(file_id) or {}
        original = asr_result.get("original_filename") or f"file_{file_id}"
        base = original.rsplit(".", 1)[0]
        subtitle_service.record_export(
            subtitle_id=None,
            fmt="srt",
            filename=f"{base}_roman_urdu.srt",
            file_id=file_id,
        )
    except Exception:
        pass

    return SRTResponse(
        file_id=file_id,
        srt_content=srt_content
    )
