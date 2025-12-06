# Temporary File Storage Strategy

## Overview

Media files (video/audio) are **temporary** and **automatically deleted** after ASR transcription is complete.

---

## How It Works

### 1. File Upload
```
User uploads file → Saved to disk + Database record created
```
- Physical file: `/tmp/romasub_uploads/{file_id}.{ext}`
- Database: `media_files` table tracks metadata

### 2. Audio Extraction (if video)
```
Video file → FFmpeg extracts audio → Audio saved temporarily
```
- Audio file: `/tmp/romasub_uploads/{file_id}_audio.wav`
- Database: `audio_path` field updated

### 3. ASR Transcription
```
Audio file → Whisper transcribes → Returns text + timestamps
```
- Transcription result stored **in-memory** (not database)
- Result accessible via `ASRService.get_transcription_result(file_id)`

### 4. **Auto-Cleanup** (NEW)
```
Transcription complete → Files automatically deleted → Only result remains
```
- ✅ Original file deleted
- ✅ Extracted audio deleted
- ✅ Database record removed
- ✅ Transcription result kept in memory

---

## Auto-Cleanup Behavior

### Default: Files Are Deleted Automatically

By default, **files are deleted immediately after transcription**:

```python
# Default behavior (auto_cleanup=True)
POST /asr/transcribe/{file_id}
{
    "language": "ur"
    // auto_cleanup defaults to True
}
```

### Optional: Keep Files Temporarily

To keep files for manual cleanup:

```python
# Keep files (auto_cleanup=False)
POST /asr/transcribe/{file_id}
{
    "language": "ur",
    "auto_cleanup": false
}

# Then manually delete later:
DELETE /media/{file_id}
```

---

## File Lifecycle

```
Upload → Processing → Transcription → Auto-Cleanup
  ↓          ↓             ↓               ↓
Disk +    Audio        Whisper        Files DELETED
 DB      Extraction      ASR          (DB + Disk)
                                      Result in Memory
```

**Timeline:**
1. **Upload** (0s): File saved (disk + DB)
2. **Extract** (~5-30s): Audio extracted from video
3. **Transcribe** (~1-5min): Whisper processes audio
4. **Cleanup** (instant): All files deleted automatically
5. **Result**: Only transcription text remains (in-memory)

---

## Why This Approach?

### ✅ Benefits

1. **No Permanent Storage** - Files don't accumulate on disk
2. **Automatic Cleanup** - No manual file management needed
3. **Database Tracking** - Track processing status while files exist
4. **Secure** - Files removed immediately after use
5. **Cost Efficient** - No long-term storage costs

### ⚠️ Considerations

1. **Transcription Results in Memory** - Lost on server restart
2. **No File Recovery** - Files deleted after processing
3. **Re-transcribe Requires Re-upload** - Cannot retry from same file

---

## Repository Pattern Still Needed?

### YES! Here's why:

#### During File Lifecycle (Before Cleanup)
- ✅ Track upload progress
- ✅ Track processing status (uploaded → processing → completed)
- ✅ Associate files with users
- ✅ Handle concurrent uploads
- ✅ Prevent duplicate processing

#### MediaRepository Provides
- `create_file_record()` - Track new uploads
- `update_status()` - Track processing progress
- `delete_file_completely()` - Clean up everything (DB + disk)
- `get_user_files()` - See user's active uploads

#### Example Flow:
```python
# 1. Upload
media_file = MediaRepository.create_file_record(db, {
    "file_id": "abc123",
    "user_id": user.id,
    "status": "uploaded"
})

# 2. Extraction
MediaRepository.update_status(db, "abc123", "processing")
# ... extract audio ...
MediaRepository.update_audio_path(db, "abc123", audio_path)

# 3. Transcription
MediaRepository.update_status(db, "abc123", "transcribing")
# ... whisper processes ...

# 4. Auto-Cleanup
MediaRepository.delete_file_completely(db, "abc123")
# ✅ DB record deleted
# ✅ Original file deleted
# ✅ Audio file deleted
```

---

## API Reference

### Upload File
```http
POST /media/upload
Content-Type: multipart/form-data

file: <video or audio file>
```
**Result:** File saved temporarily, `file_id` returned

### Transcribe with Auto-Cleanup (Default)
```http
POST /asr/transcribe/{file_id}
Content-Type: application/json

{
    "language": "ur",
    "auto_cleanup": true  // Default
}
```
**Result:** Transcription returned, files deleted automatically

### Transcribe without Auto-Cleanup
```http
POST /asr/transcribe/{file_id}
Content-Type: application/json

{
    "language": "ur",
    "auto_cleanup": false
}
```
**Result:** Transcription returned, files remain

### Manual Cleanup (if auto_cleanup=false)
```http
DELETE /media/{file_id}
```
**Result:** Files and DB record deleted

---

## Database Schema

### media_files Table (Temporary Records)

```sql
CREATE TABLE media_files (
    id SERIAL PRIMARY KEY,
    file_id VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER REFERENCES users(id),

    original_filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    extension VARCHAR(10) NOT NULL,
    is_video BOOLEAN NOT NULL,

    file_path VARCHAR(500) NOT NULL,
    audio_path VARCHAR(500),

    status VARCHAR(50) DEFAULT 'uploaded',  -- uploaded, processing, transcribing
    duration_seconds FLOAT,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

**Note:** Records are deleted automatically after transcription completes.

---

## Configuration

### Environment Variables

```env
# File Upload
MAX_FILE_SIZE_MB=500
ALLOWED_VIDEO_EXTENSIONS=mp4,avi,mkv,mov,webm
ALLOWED_AUDIO_EXTENSIONS=mp3,wav,m4a,flac,ogg

# Storage (temporary)
TEMP_UPLOAD_DIR=/tmp/romasub_uploads

# Auto-cleanup (default behavior)
# No configuration needed - always enabled by default
```

---

## Error Handling

### Files Cleaned Up Even on Errors

If transcription fails, files are still deleted:

```python
try:
    # ... transcription ...
    result = whisper.transcribe(audio_path)

    # Cleanup on success
    if auto_cleanup:
        cleanup_files(file_id)

    return result

except Exception as e:
    # Cleanup even on error
    if auto_cleanup:
        cleanup_files(file_id)

    raise
```

---

## Future Enhancements

### Option 1: Background Job for Old Files
Clean up files older than X hours:
```python
# Cleanup files stuck in "processing" for > 1 hour
async def cleanup_old_files():
    cutoff_time = datetime.now() - timedelta(hours=1)
    old_files = MediaRepository.get_files_before(db, cutoff_time)
    for file in old_files:
        MediaRepository.delete_file_completely(db, file.file_id)
```

### Option 2: TTL (Time-To-Live) for Files
```python
# Auto-delete files after 2 hours regardless of status
MEDIA_FILE_TTL_HOURS = 2
```

### Option 3: Export Before Cleanup
```python
# Export transcription to file before deleting media
if auto_cleanup:
    save_transcription_to_file(result, f"{file_id}.json")
    cleanup_files(file_id)
```

---

## Summary

| Aspect | Status |
|--------|--------|
| **Storage Type** | Temporary (auto-deleted) |
| **Default Behavior** | Files deleted after transcription |
| **Database Tracking** | Yes (during processing only) |
| **Result Storage** | In-memory (transcription text) |
| **Repository Pattern** | Still needed for lifecycle management |
| **Manual Cleanup** | Optional (set `auto_cleanup=false`) |

**Bottom Line:** Files are tracked in the database **temporarily** while being processed, then automatically cleaned up. Repository pattern is still valuable for managing the file lifecycle.
