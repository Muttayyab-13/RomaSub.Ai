"""
Subtitle Router for RomaSub.AI
Handles subtitle project CRUD, editing, and export operations
"""

from fastapi import APIRouter, HTTPException, status
from typing import Optional

from app.services import subtitle as subtitle_service
from app.services import media as media_service
from app.services import asr as asr_service
from app.schemas.subtitle import (
    CreateSubtitleRequest,
    UpdateSegmentRequest,
    AddSegmentRequest,
    BulkUpdateRequest,
    SubtitleProjectResponse,
    SegmentResponse,
    ExportResponse,
    SubtitleSegmentSchema,
)

router = APIRouter(prefix="/subtitles", tags=["Subtitles"])


# ============================================================================
# Project Endpoints
# ============================================================================

@router.post("/create/{file_id}", response_model=SubtitleProjectResponse)
async def create_subtitle_project(file_id: str, request: CreateSubtitleRequest = None):
    """
    Create a new subtitle project from transcription results.

    - **file_id**: ID of the transcribed media file
    - **project_name**: Optional name for the project
    - **segments**: Optional segments to initialize with (fetched from transcription if omitted)
    """
    # Get file info for filename
    file_info = media_service.get_file_info(file_id)
    original_filename = file_info["original_filename"] if file_info else f"file_{file_id}"

    # Get duration
    transcription = asr_service.get_transcription_result(file_id)
    duration = transcription.get("audio_duration_seconds") if transcription else None

    # Build segments from request if provided
    segments = None
    if request and request.segments:
        segments = [seg.model_dump() for seg in request.segments]

    project_name = request.project_name if request else None

    success, message, project = subtitle_service.create_project(
        file_id=file_id,
        original_filename=original_filename,
        duration=duration,
        project_name=project_name,
        segments=segments,
    )

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return SubtitleProjectResponse(
        subtitle_id=project["subtitle_id"],
        file_id=project["file_id"],
        project_name=project["project_name"],
        original_filename=project["original_filename"],
        segments=[SubtitleSegmentSchema(**s) for s in project["segments"]],
        segment_count=project["segment_count"],
        file_duration=project.get("file_duration"),
        created_at=project["created_at"],
        updated_at=project["updated_at"],
    )


@router.get("/{subtitle_id}", response_model=SubtitleProjectResponse)
async def get_subtitle_project(subtitle_id: str):
    """Get a subtitle project by ID."""
    project = subtitle_service.get_project(subtitle_id)
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    return SubtitleProjectResponse(
        subtitle_id=project["subtitle_id"],
        file_id=project["file_id"],
        project_name=project["project_name"],
        original_filename=project["original_filename"],
        segments=[SubtitleSegmentSchema(**s) for s in project["segments"]],
        segment_count=project["segment_count"],
        file_duration=project.get("file_duration"),
        created_at=project["created_at"],
        updated_at=project["updated_at"],
    )


# ============================================================================
# Segment Editing Endpoints
# ============================================================================

@router.put("/{subtitle_id}/segments/{segment_id}", response_model=SegmentResponse)
async def update_segment(subtitle_id: str, segment_id: int, request: UpdateSegmentRequest):
    """
    Update a single subtitle segment's text or timing.

    - **subtitle_id**: Project ID
    - **segment_id**: Segment ID within the project
    """
    success, message, segment = subtitle_service.update_segment(
        subtitle_id=subtitle_id,
        segment_id=segment_id,
        roman_urdu_text=request.roman_urdu_text,
        urdu_text=request.urdu_text,
        start=request.start,
        end=request.end,
    )

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return SegmentResponse(
        success=True,
        message=message,
        segment=SubtitleSegmentSchema(**segment),
    )


@router.post("/{subtitle_id}/segments", response_model=SegmentResponse)
async def add_segment(subtitle_id: str, request: AddSegmentRequest):
    """
    Add a new subtitle segment after the specified segment.

    - **subtitle_id**: Project ID
    - **after_segment_id**: Insert after this segment
    """
    success, message, segment = subtitle_service.add_segment(
        subtitle_id=subtitle_id,
        after_segment_id=request.after_segment_id,
        start=request.start,
        end=request.end,
        roman_urdu_text=request.roman_urdu_text,
        urdu_text=request.urdu_text,
    )

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return SegmentResponse(
        success=True,
        message=message,
        segment=SubtitleSegmentSchema(**segment),
    )


@router.delete("/{subtitle_id}/segments/{segment_id}")
async def delete_segment(subtitle_id: str, segment_id: int):
    """Delete a subtitle segment."""
    success, message = subtitle_service.delete_segment(subtitle_id, segment_id)

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return {"success": True, "message": message}


@router.put("/{subtitle_id}/bulk-update", response_model=SubtitleProjectResponse)
async def bulk_update_segments(subtitle_id: str, request: BulkUpdateRequest):
    """
    Batch update all segments (used for auto-save).

    Replaces all segments in the project with the provided list.
    """
    segments = [seg.model_dump() for seg in request.segments]
    success, message, project = subtitle_service.bulk_update(subtitle_id, segments)

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return SubtitleProjectResponse(
        subtitle_id=project["subtitle_id"],
        file_id=project["file_id"],
        project_name=project["project_name"],
        original_filename=project["original_filename"],
        segments=[SubtitleSegmentSchema(**s) for s in project["segments"]],
        segment_count=project["segment_count"],
        file_duration=project.get("file_duration"),
        created_at=project["created_at"],
        updated_at=project["updated_at"],
    )


# ============================================================================
# Auto-fix & Export
# ============================================================================

@router.post("/{subtitle_id}/fix-overlaps")
async def fix_timing_overlaps(subtitle_id: str):
    """Auto-fix timing overlaps between segments (ensures 0.1s minimum gap)."""
    success, message, segments = subtitle_service.fix_overlaps(subtitle_id)

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    return {
        "success": True,
        "message": message,
        "segments": [SubtitleSegmentSchema(**s) for s in segments],
    }


@router.get("/{subtitle_id}/export", response_model=ExportResponse)
async def export_subtitles(subtitle_id: str, format: str = "srt"):
    """
    Export subtitles in the specified format.

    - **format**: Export format - `srt`, `vtt`, or `txt`
    """
    success, message, content, filename = subtitle_service.export_subtitles(subtitle_id, format)

    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    # Record in export history
    subtitle_service.record_export(subtitle_id, format, filename)

    return ExportResponse(
        subtitle_id=subtitle_id,
        format=format,
        content=content,
        filename=filename,
    )


@router.get("/list/projects")
async def list_projects():
    """List all subtitle projects (summary, no full segments)."""
    return {"success": True, "projects": subtitle_service.list_all_projects()}


@router.get("/list/exports")
async def list_exports():
    """List export history."""
    return {"success": True, "exports": subtitle_service.list_exports()}
