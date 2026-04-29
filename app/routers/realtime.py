"""
Realtime Streaming Router for RomaSub.AI
Handles SSE subtitle streaming, seek reprioritization, and session status.
"""

import asyncio
import json
import os
import time
import logging

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from app.config import settings
from app.services import media as media_service
from app.services import chunker_service
from app.services import session_manager
from app.services.session_manager import ProcessingSession
from app.schemas.realtime import SeekRequest, SessionStatusResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/realtime", tags=["Realtime Streaming"])

BUFFER_CHUNK_COUNT = 3  # Number of chunks to process before signaling playback start


# ============================================================================
# SSE Streaming Endpoint
# ============================================================================

@router.get("/stream/{file_id}")
async def stream_subtitles(file_id: str, language: str = "ur"):
    """
    Server-Sent Events endpoint for real-time subtitle streaming.

    Fast-path: If batch transcription already completed for this file,
    emits all existing segments instantly without re-processing.

    Slow-path: Extracts audio, chunks it, processes via priority queue,
    streams SSE events as each chunk completes.

    Use POST /realtime/seek/{file_id} to reprioritize for seeking.
    """
    from app.services.asr import get_transcription_result

    # Validate file exists
    file_info = media_service.get_file_info(file_id)
    if not file_info:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")

    # ===== FAST PATH: batch transcription already done =====
    existing = get_transcription_result(file_id)
    if existing and existing.get("status") == "completed":
        logger.info("Session %s: fast-path — using existing transcription", file_id)
        return StreamingResponse(
            _emit_cached_results(file_id, existing),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    # ===== SLOW PATH: chunked processing =====

    # Extract audio if needed (reuse existing service)
    success, audio_path = media_service.extract_audio(file_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Audio extraction failed: {audio_path}",
        )

    # Get audio duration
    duration = media_service.get_audio_duration(audio_path)
    if not duration or duration <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not determine audio duration",
        )

    # Compute chunk plan
    chunks = chunker_service.compute_chunk_plan(duration)
    if not chunks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio too short to process",
        )

    # Create or get existing session
    session = session_manager.create_session(file_id, audio_path, duration, chunks)
    session.enqueue_initial_chunks(BUFFER_CHUNK_COUNT)

    # Launch background processing task
    task = asyncio.create_task(_process_chunks(session, language))

    async def event_generator():
        try:
            while True:
                try:
                    event = await asyncio.wait_for(
                        session.event_queue.get(),
                        timeout=300.0,  # 5 min timeout for stale sessions
                    )
                except asyncio.TimeoutError:
                    # Send keepalive
                    yield f": keepalive\n\n"
                    continue

                event_type = event["event"]
                event_data = json.dumps(event["data"])
                yield f"event: {event_type}\ndata: {event_data}\n\n"

                # End stream on terminal events
                if event_type in ("stream_complete", "error"):
                    break
        except asyncio.CancelledError:
            pass
        finally:
            # Client disconnected or stream ended
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )


# ============================================================================
# Fast-Path: Emit Cached Results
# ============================================================================

async def _emit_cached_results(file_id: str, transcription: dict):
    """
    When batch transcription already completed, emit all segments instantly
    as SSE events without re-processing through Whisper/M2M100.
    """
    urdu_segments = transcription.get("segments", [])
    roman_segments = transcription.get("roman_urdu_segments", [])
    duration = transcription.get("audio_duration_seconds", 0.0)

    # Build segments matching the subtitle schema format
    segments = []
    for i, urdu_seg in enumerate(urdu_segments):
        roman_seg = roman_segments[i] if i < len(roman_segments) else {}
        segments.append({
            "id": i,
            "start": urdu_seg.get("start", 0.0),
            "end": urdu_seg.get("end", 0.0),
            "urdu_text": urdu_seg.get("text", ""),
            "roman_urdu_text": roman_seg.get("roman_urdu_text", ""),
            "is_edited": False,
        })

    max_end = max((s["end"] for s in segments), default=0.0) if segments else 0.0

    # Emit all segments as a single chunk_ready
    chunk_ready_data = json.dumps({
        "chunk_index": 0,
        "segments": segments,
        "processed_through": max_end,
        "chunks_done": 1,
        "chunks_total": 1,
    })
    yield f"event: chunk_ready\ndata: {chunk_ready_data}\n\n"

    # Immediately emit buffer_ready
    buffer_data = json.dumps({
        "playback_start": True,
        "processed_seconds": max_end,
        "total_duration": duration or max_end,
        "chunks_ready": 1,
        "total_chunks": 1,
    })
    yield f"event: buffer_ready\ndata: {buffer_data}\n\n"

    # Immediately emit stream_complete
    complete_data = json.dumps({
        "total_segments": len(segments),
        "total_duration": duration or max_end,
        "processing_time_seconds": 0.0,
    })
    yield f"event: stream_complete\ndata: {complete_data}\n\n"

    logger.info(
        "Session %s: fast-path complete — %d cached segments emitted instantly",
        file_id, len(segments),
    )


# ============================================================================
# Background Chunk Processing
# ============================================================================

async def _process_chunks(session: ProcessingSession, language: str) -> None:
    """
    Background coroutine that processes chunks from the priority queue.
    Each chunk: extract audio → Whisper → transliterate → emit SSE event.
    """
    buffer_count = min(BUFFER_CHUNK_COUNT, len(session.chunks))
    loop = asyncio.get_event_loop()

    try:
        while not session.priority_queue.empty() and not session.cancelled:
            # Pop highest-priority chunk
            _priority, chunk_index = await session.priority_queue.get()

            # Skip already-processed chunks (can happen after reprioritization)
            if session.chunk_status[chunk_index] == "done":
                continue

            session.chunk_status[chunk_index] = "processing"

            try:
                # Run synchronous Whisper/M2M100 in thread pool
                segments = await loop.run_in_executor(
                    None,
                    _process_single_chunk,
                    session,
                    chunk_index,
                    language,
                )

                session.chunk_status[chunk_index] = "done"
                session.add_completed_segments(chunk_index, segments)

                # Emit chunk_ready event
                await session.emit_event("chunk_ready", {
                    "chunk_index": chunk_index,
                    "segments": [_segment_to_dict(s) for s in segments],
                    "processed_through": session.processed_through,
                    "chunks_done": session.chunks_done,
                    "chunks_total": len(session.chunks),
                })

                # Emit buffer_ready after initial chunks
                if session.chunks_done == buffer_count and session.status == "buffering":
                    session.status = "streaming"
                    await session.emit_event("buffer_ready", {
                        "playback_start": True,
                        "processed_seconds": session.processed_through,
                        "total_duration": session.duration,
                        "chunks_ready": buffer_count,
                        "total_chunks": len(session.chunks),
                    })

            except Exception as e:
                logger.error(
                    "Session %s: chunk %d failed: %s",
                    session.file_id, chunk_index, str(e),
                )
                session.chunk_status[chunk_index] = "pending"
                # Continue with next chunk instead of aborting
                continue

        # All chunks processed
        if not session.cancelled:
            session.status = "complete"
            processing_time = time.time() - session.started_at
            await session.emit_event("stream_complete", {
                "total_segments": len(session.all_segments),
                "total_duration": session.duration,
                "processing_time_seconds": round(processing_time, 2),
            })
            logger.info(
                "Session %s: complete — %d segments in %.1fs",
                session.file_id, len(session.all_segments), processing_time,
            )

    except asyncio.CancelledError:
        logger.info("Session %s: processing cancelled", session.file_id)
        session.cancelled = True
    except Exception as e:
        logger.error("Session %s: processing error: %s", session.file_id, str(e))
        session.status = "error"
        await session.emit_event("error", {"message": str(e)})


def _process_single_chunk(
    session: ProcessingSession,
    chunk_index: int,
    language: str,
) -> list:
    """
    Synchronous function that processes a single chunk.
    Runs in a thread pool via run_in_executor.

    1. Extract chunk audio via FFmpeg
    2. Transcribe with Whisper (reuse lazy-loaded model)
    3. Offset timestamps to absolute positions
    4. Trim overlap region (non-first chunks)
    5. Transliterate with M2M100 (reuse lazy-loaded model)
    6. Cleanup temp chunk file
    """
    from app.services.asr import transcribe_chunk
    from app.services.transliteration import transliterate_text

    chunk = session.chunks[chunk_index]

    logger.info(
        "Session %s: processing chunk %d (%.1fs-%.1fs)",
        session.file_id, chunk_index, chunk["start"], chunk["end"],
    )

    # 1. Extract chunk audio
    chunk_audio_path = chunker_service.extract_chunk_audio(
        session.audio_path,
        chunk,
        settings.temp_upload_dir,
    )

    try:
        # 2. Transcribe with Whisper
        result = transcribe_chunk(chunk_audio_path, language=language)
        raw_segments = result["segments"]

        # 3. Offset timestamps to absolute position
        segments = chunker_service.offset_segments(raw_segments, chunk["start"])

        # 4. Trim overlap for non-first chunks
        if chunk_index > 0:
            segments = chunker_service.trim_overlap_segments(
                segments, chunk["start"], chunker_service.OVERLAP_DURATION,
            )

        # 5. Transliterate each segment
        for seg in segments:
            seg["urdu_text"] = seg.pop("text")
            seg["roman_urdu_text"] = transliterate_text(seg["urdu_text"])
            seg["is_edited"] = False

        # Re-sequence IDs
        for i, seg in enumerate(segments):
            seg["id"] = i

        # Optional LLM refine pass (no-op when disabled; falls back on failure)
        try:
            from app.services.llm_refiner import refine_segments
            refine_segments(segments)
        except Exception as e:
            logger.warning(
                "Session %s: chunk %d refine failed, using raw m2m100: %s",
                session.file_id, chunk_index, str(e),
            )

        logger.info(
            "Session %s: chunk %d done — %d segments",
            session.file_id, chunk_index, len(segments),
        )
        return segments

    finally:
        # 6. Cleanup temp chunk file
        chunker_service.cleanup_chunk_file(chunk_audio_path)


def _segment_to_dict(seg: dict) -> dict:
    """Ensure segment dict matches SubtitleSegmentSchema shape."""
    return {
        "id": seg.get("id", 0),
        "start": seg.get("start", 0.0),
        "end": seg.get("end", 0.0),
        "urdu_text": seg.get("urdu_text", ""),
        "roman_urdu_text": seg.get("roman_urdu_text", ""),
        "is_edited": seg.get("is_edited", False),
    }


# ============================================================================
# Seek Endpoint
# ============================================================================

@router.post("/seek/{file_id}")
async def seek_to_position(file_id: str, request: SeekRequest):
    """
    Reprioritize chunk processing so the chunk covering target_seconds
    is processed next. Returns immediately; reprioritization happens async.
    """
    session = session_manager.get_session(file_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active streaming session for this file",
        )

    if session.status == "complete":
        return {"success": True, "message": "All chunks already processed"}

    session.reprioritize_for_seek(request.target_seconds)
    return {
        "success": True,
        "message": f"Reprioritized for {request.target_seconds:.1f}s",
    }


# ============================================================================
# Status Endpoint (polling fallback)
# ============================================================================

@router.get("/status/{file_id}", response_model=SessionStatusResponse)
async def get_session_status(file_id: str):
    """Get current processing status for a streaming session."""
    session = session_manager.get_session(file_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active session for this file",
        )

    return SessionStatusResponse(
        file_id=session.file_id,
        status=session.status,
        chunks_done=session.chunks_done,
        chunks_total=len(session.chunks),
        processed_through=session.processed_through,
        segments_count=len(session.all_segments),
        total_duration=session.duration,
    )
