"""
Migration script to add profile_picture_url column to users table
"""
from app.database import engine
from sqlalchemy import text

def add_profile_picture_column():
    """Add profile_picture_url column to users table if it doesn't exist"""
    with engine.connect() as conn:
        # Check if column exists
        result = conn.execute(text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name='users' AND column_name='profile_picture_url';
        """))

        if result.fetchone() is None:
            # Column doesn't exist, add it
            conn.execute(text("""
                ALTER TABLE users
                ADD COLUMN profile_picture_url VARCHAR(500);
            """))
            conn.commit()
            print("Column 'profile_picture_url' added successfully!")
        else:
            print("Column 'profile_picture_url' already exists!")

if __name__ == "__main__":
    add_profile_picture_column()
