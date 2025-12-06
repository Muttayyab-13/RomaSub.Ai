# Database Migration Guide

## MediaFile Table Migration

After implementing the repository pattern, you need to add the `media_files` table to your database.

### Option 1: Using Alembic (Recommended for Production)

1. Install Alembic if not already installed:
```bash
pip install alembic
```

2. Initialize Alembic (if not already done):
```bash
alembic init alembic
```

3. Update `alembic.ini` with your database URL or configure `alembic/env.py` to use your config.

4. Create a new migration:
```bash
alembic revision --autogenerate -m "Add media_files table"
```

5. Review the generated migration file in `alembic/versions/`

6. Run the migration:
```bash
alembic upgrade head
```

### Option 2: Manual SQL (Quick Setup)

Run this SQL directly in your PostgreSQL database:

```sql
-- Create media_files table
CREATE TABLE media_files (
    id SERIAL PRIMARY KEY,
    file_id VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,

    -- File metadata
    original_filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    extension VARCHAR(10) NOT NULL,
    is_video BOOLEAN NOT NULL,

    -- File paths
    file_path VARCHAR(500) NOT NULL,
    audio_path VARCHAR(500),

    -- Processing status
    status VARCHAR(50) DEFAULT 'uploaded',

    -- Media properties
    duration_seconds FLOAT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_media_files_file_id ON media_files(file_id);
CREATE INDEX idx_media_files_user_id ON media_files(user_id);
```

### Option 3: Using SQLAlchemy (Development)

Add this to your main.py or create a separate script:

```python
from app.database import engine, Base
from app.models.media import MediaFile  # This imports the model

# Create all tables
Base.metadata.create_all(bind=engine)
```

Then run:
```bash
python -c "from app.database import engine, Base; from app.models.media import MediaFile; Base.metadata.create_all(bind=engine)"
```

## Verify Migration

After running the migration, verify the table exists:

```sql
\dt media_files  -- In psql
```

Or in Python:
```python
from app.database import SessionLocal
from app.repositories.media_repository import MediaRepository

db = SessionLocal()
# Try to query - should not error
result = MediaRepository.get_by_file_id(db, "test")
print("Migration successful!" if result is None else "Found existing records")
db.close()
```

## Rollback (if needed)

If using Alembic:
```bash
alembic downgrade -1
```

If using manual SQL:
```sql
DROP TABLE media_files;
```

## Notes

- The `media_files` table has a foreign key to `users(id)` with CASCADE delete
- If a user is deleted, all their media files will be automatically removed from the database
- Physical files need to be cleaned up separately (this is handled by MediaRepository.delete_file_completely)
