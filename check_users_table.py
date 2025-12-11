"""
Script to check the users table schema
"""
from app.database import engine
from sqlalchemy import text

def check_users_table():
    """Check columns in users table"""
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_name='users'
            ORDER BY ordinal_position;
        """))

        print("Columns in 'users' table:")
        print("-" * 60)
        for row in result:
            print(f"{row[0]:30} {row[1]:20} nullable={row[2]}")

if __name__ == "__main__":
    check_users_table()
