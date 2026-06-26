"""
Pydantic schemas for subtitle editing operations
Handles request/response validation for the subtitle editor module
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime


class SubtitleSegmentSchema(BaseModel):
    """Schema for a single subtitle segment"""
    id: int
    start: float = Field(..., ge=0.0, description="Start time in seconds")
    end: float = Field(..., ge=0.0, description="End time in seconds")
    urdu_text: str = Field("", max_length=500, description="Original Urdu text")
    roman_urdu_text: str = Field("", max_length=500, description="Roman Urdu text")
    is_edited: bool = False

    @validator('end')
    def end_after_start(cls, v, values):
        if 'start' in values and v <= values['start']:
            raise ValueError('End time must be after start time')
        return v

    @validator('roman_urdu_text', 'urdu_text')
    def text_not_too_long(cls, v):
        if len(v) > 500:
            raise ValueError('Text must not exceed 500 characters')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "id": 1,
                "start": 0.0,
                "end": 3.5,
                "urdu_text": "سلام",
                "roman_urdu_text": "Salam",
                "is_edited": False
            }
        }


class CreateSubtitleRequest(BaseModel):
    """Request to create a subtitle project from transcription"""
    project_name: Optional[str] = Field(None, max_length=255, description="Optional project name")
    segments: Optional[List[SubtitleSegmentSchema]] = Field(None, description="Segments to initialize with (optional, fetched from transcription if omitted)")

    class Config:
        json_schema_extra = {
            "example": {
                "project_name": "My Video Subtitles"
            }
        }


class UpdateSegmentRequest(BaseModel):
    """Request to update a single segment"""
    roman_urdu_text: Optional[str] = Field(None, max_length=500)
    urdu_text: Optional[str] = Field(None, max_length=500)
    start: Optional[float] = Field(None, ge=0.0)
    end: Optional[float] = Field(None, ge=0.0)

    class Config:
        json_schema_extra = {
            "example": {
                "roman_urdu_text": "Updated text",
                "start": 1.0,
                "end": 4.5
            }
        }


class AddSegmentRequest(BaseModel):
    """Request to add a new segment"""
    after_segment_id: int = Field(..., description="Insert after this segment ID")
    start: float = Field(..., ge=0.0, description="Start time in seconds")
    end: float = Field(..., ge=0.0, description="End time in seconds")
    roman_urdu_text: str = Field("", max_length=500)
    urdu_text: str = Field("", max_length=500)

    @validator('end')
    def end_after_start(cls, v, values):
        if 'start' in values and v <= values['start']:
            raise ValueError('End time must be after start time')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "after_segment_id": 2,
                "start": 5.0,
                "end": 8.0,
                "roman_urdu_text": "New subtitle",
                "urdu_text": ""
            }
        }


class BulkUpdateRequest(BaseModel):
    """Request for batch segment update (auto-save)"""
    segments: List[SubtitleSegmentSchema]


class SubtitleProjectResponse(BaseModel):
    """Response containing full subtitle project"""
    success: bool = True
    subtitle_id: str
    file_id: str
    project_name: str
    original_filename: str
    segments: List[SubtitleSegmentSchema]
    segment_count: int
    file_duration: Optional[float] = None
    created_at: str
    updated_at: str
    is_video: bool = False


class SegmentResponse(BaseModel):
    """Response for single segment operations"""
    success: bool = True
    message: str
    segment: Optional[SubtitleSegmentSchema] = None


class ExportResponse(BaseModel):
    """Response for subtitle export"""
    success: bool = True
    subtitle_id: str
    format: str
    content: str
    filename: str
