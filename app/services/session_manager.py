"""
Processing Session Manager for RomaSub.AI
Manages real-time subtitle processing sessions with priority-based chunk queues.

Each session tracks: chunk processing state, accumulated segments, SSE event queue,
and an asyncio PriorityQueue that supports seek-based reprioritization.
"""

import asyncio
import time
from typing import Dict, List, Optional
import logging

from app.services import chunker_service

logger = logging.getLogger(__name__)

# ============================================================================
# Module-level state for active sessions
# ============================================================================

_active_sessions: Dict[str, 'ProcessingSession'] = {}


# ============================================================================
# Processing Session
# ============================================================================

class ProcessingSession:
    """
    Manages state for a single real-time subtitle processing session.

    Lifecycle: create → enqueue_initial_chunks → process loop pops from
    priority_queue → emit events → stream_complete or cancelled.
    """

    def __init__(
        self,
        file_id: str,
        audio_path: str,
        duration: float,
        chunks: List[Dict],
    ):
        self.file_id = file_id
        self.audio_path = audio_path
        self.duration = duration
        self.chunks = chunks

        # Chunk state tracking
        self.chunk_status: Dict[int, str] = {
            c["index"]: "pending" for c in chunks
        }

        # Accumulated subtitle segments (sorted by start time)
        self.all_segments: List[Dict] = []
        self.processed_through: float = 0.0  # highest end_time of completed chunk

        # Async queues
        self.event_queue: asyncio.Queue = asyncio.Queue()
        self.priority_queue: asyncio.PriorityQueue = asyncio.PriorityQueue()

        # Session metadata
        self.status: str = "buffering"  # buffering | streaming | complete | error
        self.started_at: float = time.time()
        self.cancelled: bool = False
        self.chunks_done: int = 0

    def enqueue_initial_chunks(self, buffer_count: int = 3) -> None:
        """
        Enqueue chunks into the priority queue.
        First buffer_count chunks get priority 0 (highest).
        Remaining chunks get priority 1 (sequential background).
        """
        actual_buffer = min(buffer_count, len(self.chunks))

        for i in range(actual_buffer):
            self.priority_queue.put_nowait((0, i))

        for i in range(actual_buffer, len(self.chunks)):
            self.priority_queue.put_nowait((1, i))

        logger.info(
            "Session %s: enqueued %d chunks (%d buffer, %d background)",
            self.file_id, len(self.chunks), actual_buffer,
            len(self.chunks) - actual_buffer,
        )

    def reprioritize_for_seek(self, target_seconds: float) -> None:
        """
        Reprioritize the chunk queue so that the chunk covering target_seconds
        (and 2 chunks ahead) are processed next.

        Drains the current queue, re-inserts pending chunks with updated priorities.
        """
        # Find target chunk index
        target_chunk = int(target_seconds // chunker_service.STEP_SIZE)
        target_chunk = min(target_chunk, len(self.chunks) - 1)

        # Urgent chunks: target and 2 ahead
        urgent_indices = set()
        for i in range(target_chunk, min(target_chunk + 3, len(self.chunks))):
            if self.chunk_status[i] != "done":
                urgent_indices.add(i)

        if not urgent_indices:
            logger.info(
                "Session %s: seek to %.1fs — all target chunks already processed",
                self.file_id, target_seconds,
            )
            return

        # Drain the current queue
        pending_indices = []
        while not self.priority_queue.empty():
            try:
                _, chunk_index = self.priority_queue.get_nowait()
                if self.chunk_status[chunk_index] != "done":
                    pending_indices.append(chunk_index)
            except asyncio.QueueEmpty:
                break

        # Re-enqueue with updated priorities
        for idx in pending_indices:
            if idx in urgent_indices:
                self.priority_queue.put_nowait((0, idx))  # urgent
            else:
                self.priority_queue.put_nowait((1, idx))  # normal

        # Also enqueue urgent chunks that weren't in the queue
        # (they may not have been in queue if already popped but not yet processed)
        for idx in urgent_indices:
            if idx not in pending_indices and self.chunk_status[idx] == "pending":
                self.priority_queue.put_nowait((0, idx))

        logger.info(
            "Session %s: reprioritized for seek to %.1fs — urgent chunks: %s",
            self.file_id, target_seconds, sorted(urgent_indices),
        )

    def add_completed_segments(self, chunk_index: int, segments: List[Dict]) -> None:
        """
        Merge new segments into all_segments maintaining sorted order by start time.
        Updates processed_through to the highest end_time seen.
        """
        self.all_segments.extend(segments)
        self.all_segments.sort(key=lambda s: s["start"])

        chunk = self.chunks[chunk_index]
        if chunk["end"] > self.processed_through:
            self.processed_through = chunk["end"]

        self.chunks_done += 1

    async def emit_event(self, event_type: str, data: dict) -> None:
        """Push an SSE event to the queue for the streaming generator."""
        await self.event_queue.put({
            "event": event_type,
            "data": data,
        })


# ============================================================================
# Session Lifecycle Functions
# ============================================================================

def create_session(
    file_id: str,
    audio_path: str,
    duration: float,
    chunks: List[Dict],
) -> 'ProcessingSession':
    """
    Create a new processing session. If one already exists for this file_id,
    return the existing session (idempotent).
    """
    if file_id in _active_sessions:
        existing = _active_sessions[file_id]
        if existing.status not in ("complete", "error"):
            logger.info("Session %s: returning existing active session", file_id)
            return existing

    session = ProcessingSession(file_id, audio_path, duration, chunks)
    _active_sessions[file_id] = session
    logger.info("Session %s: created (%d chunks, %.1fs duration)", file_id, len(chunks), duration)
    return session


def get_session(file_id: str) -> Optional['ProcessingSession']:
    """Get an active session by file_id."""
    return _active_sessions.get(file_id)


def remove_session(file_id: str) -> None:
    """Remove a session from the active sessions dict."""
    if file_id in _active_sessions:
        session = _active_sessions.pop(file_id)
        session.cancelled = True
        logger.info("Session %s: removed", file_id)
