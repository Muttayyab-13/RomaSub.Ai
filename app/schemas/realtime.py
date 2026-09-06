"""
Pydantic schemas for real-time subtitle streaming
Handles SSE events, chunk metadata, seek requests, and session status
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from app.schemas.subtitle import SubtitleSegmentSchema


class ChunkInfo(BaseModel):
    """Metadata for a single audio chunk"""
    chunk_index: int
    start_time: float  # seconds in original audio
    end_time: float
    status: str = "pending"  # pending | processing | done


class ChunkReadyData(BaseModel):
    """SSE payload when a chunk finishes processing"""
    chunk_index: int
    segments: List[SubtitleSegmentSchema]
    processed_through: float  # highest end_time processed so far
    chunks_done: int
    chunks_total: int


class BufferReadyData(BaseModel):
    """SSE payload when initial buffer is ready for playback"""
    playback_start: bool = True
    processed_seconds: float
    total_duration: float
    chunks_ready: int
    total_chunks: int


class StreamCompleteData(BaseModel):
    """SSE payload when all chunks are processed"""
    total_segments: int
    total_duration: float
    processing_time_seconds: float


class SeekRequest(BaseModel):
    """Request to reprioritize chunk processing for a seek position"""
    target_seconds: float = Field(..., ge=0.0, description="Seek target in seconds")


class SessionStatusResponse(BaseModel):
    """Polling fallback: current processing status"""
    file_id: str
    status: str  # buffering | streaming | complete | error
    chunks_done: int
    chunks_total: int
    processed_through: float
    segments_count: int
    total_duration: float
