"""
ASR Service for RomaSub.AI
Handles speech recognition using OpenAI Whisper
"""

import os
from typing import Optional, Dict, List, Tuple
from datetime import datetime
from sqlalchemy.orm import Session
import json

from app.config import settings
from app.services.media_service import MediaService
import logging

logger = logging.getLogger(__name__)

# Global variable to hold loaded Whisper model
_whisper_model = None


def get_whisper_model():
    """
    Load Whisper model (lazy loading).
    Model is loaded once and reused for all transcriptions.
    """
    global _whisper_model
    
    if _whisper_model is None:
        print(f"\n[ASR] Loading Whisper model: {settings.whisper_model}")
        print("[ASR] This may take a moment on first run...")
        
        import whisper
        _whisper_model = whisper.load_model(settings.whisper_model)
        
        print(f"[ASR] Whisper model loaded successfully!")
    
    return _whisper_model


class ASRService:
    """Service for Automatic Speech Recognition using Whisper"""
    
    # In-memory storage for transcription results (demo purposes)
    _transcription_results: Dict[str, Dict] = {}
    
    @staticmethod
    def transcribe_audio(file_id: str, language: str = "ur", auto_cleanup: bool = True) -> Tuple[bool, str, Dict]:
        """
        Transcribe audio file using Whisper.

        Args:
            file_id: ID of the uploaded file
            language: Language code (default: 'ur' for Urdu)
            auto_cleanup: If True, delete files after transcription (default: True)

        Returns:
            Tuple of (success, message, result_dict)
        """
        # Get file info
        file_info = MediaService.get_file_info(file_id)

        if not file_info:
            return False, "File not found", {}

        # Extract audio if needed
        success, audio_path = MediaService.extract_audio(file_id)
        
        if not success:
            return False, f"Audio extraction failed: {audio_path}", {}
        
        print(f"\n{'='*60}")
        print(f"[ASR] Starting transcription for file: {file_id}")
        print(f"[ASR] Audio path: {audio_path}")
        print(f"[ASR] Language: {language}")
        print(f"{'='*60}")
        
        try:
            # Load Whisper model
            model = get_whisper_model()
            
            # Get audio duration
            duration = MediaService.get_audio_duration(audio_path)
            if duration:
                print(f"[ASR] Audio duration: {duration:.2f} seconds")
            
            # Transcribe
            print("[ASR] Transcribing... (this may take a while)")
            start_time = datetime.now()
            
            result = model.transcribe(
                audio_path,
                language=language,
                task="transcribe",
                verbose=False  # Set to True for detailed output
            )
            
            end_time = datetime.now()
            processing_time = (end_time - start_time).total_seconds()
            
            # Extract segments with timestamps
            segments = []
            for segment in result.get("segments", []):
                segments.append({
                    "id": segment["id"],
                    "start": segment["start"],
                    "end": segment["end"],
                    "text": segment["text"].strip()
                })
            
            # Create result object
            transcription_result = {
                "file_id": file_id,
                "language": language,
                "text": result["text"],
                "segments": segments,
                "segment_count": len(segments),
                "processing_time_seconds": processing_time,
                "audio_duration_seconds": duration,
                "transcribed_at": datetime.now().isoformat(),
                "status": "completed"
            }
            
            # Store result
            ASRService._transcription_results[file_id] = transcription_result

            # Print results to console
            print(f"\n{'='*60}")
            print("[ASR] TRANSCRIPTION COMPLETE")
            print(f"{'='*60}")
            print(f"Processing time: {processing_time:.2f} seconds")
            print(f"Segments found: {len(segments)}")
            print(f"\n--- Full Transcription ---")
            print(result["text"])
            print(f"\n--- Segments with Timestamps ---")
            for seg in segments[:10]:  # Show first 10 segments
                print(f"[{seg['start']:.2f}s - {seg['end']:.2f}s]: {seg['text']}")
            if len(segments) > 10:
                print(f"... and {len(segments) - 10} more segments")
            print(f"{'='*60}\n")

            logger.info("Transcription completed for file: %s", file_id)

            # Auto-cleanup: Delete temporary files after transcription
            if auto_cleanup:
                print(f"[CLEANUP] Auto-deleting temporary files for: {file_id}")
                cleanup_success = MediaService.cleanup_file(file_id)
                if cleanup_success:
                    logger.info("Cleaned up temporary files for: %s", file_id)
                    print(f"[CLEANUP] Files deleted successfully")
                else:
                    logger.warning("Failed to cleanup files for: %s", file_id)
                    print(f"[CLEANUP] Warning: Failed to delete some files")

            return True, "Transcription completed", transcription_result
            
        except Exception as e:
            error_msg = f"Transcription failed: {str(e)}"
            logger.error(error_msg)
            print(f"[ASR ERROR] {error_msg}")

            # Cleanup files even on error
            if auto_cleanup:
                print(f"[CLEANUP] Cleaning up files after error...")
                MediaService.cleanup_file(file_id)

            return False, error_msg, {}
    
    @staticmethod
    def get_transcription_result(file_id: str) -> Optional[Dict]:
        """Get transcription result by file ID"""
        return ASRService._transcription_results.get(file_id)
    
    @staticmethod
    def format_as_srt(segments: List[Dict]) -> str:
        """
        Format segments as SRT subtitle format.
        
        Args:
            segments: List of segment dictionaries
            
        Returns:
            SRT formatted string
        """
        srt_lines = []
        
        for i, segment in enumerate(segments, 1):
            start = ASRService._seconds_to_srt_time(segment["start"])
            end = ASRService._seconds_to_srt_time(segment["end"])
            text = segment["text"]
            
            srt_lines.append(f"{i}")
            srt_lines.append(f"{start} --> {end}")
            srt_lines.append(text)
            srt_lines.append("")
        
        return "\n".join(srt_lines)
    
    @staticmethod
    def _seconds_to_srt_time(seconds: float) -> str:
        """Convert seconds to SRT time format (HH:MM:SS,mmm)"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


# Create singleton instance
asr_service = ASRService()
