"""
core/db.py - SQLite connection and query layer
================================================
"""

import sqlite3
from pathlib import Path

SCHEMA_PATH = Path(__file__).parent.parent / "data" / "schema.sql"
DEFAULT_DB  = Path(__file__).parent.parent / "data" / "profiler.db"


def get_connection(db_path: Path = DEFAULT_DB) -> sqlite3.Connection:
    """Return a SQLite connection with row_factory set."""
    if db_path == ":memory:":
        conn = sqlite3.connect(db_path, check_same_thread=False)
    else:
        # 2. Otherwise, treat it as a file path, convert to Path object, and create folders
        db_path = Path(db_path)
        db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(db_path, check_same_thread=False)


    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_db(conn: sqlite3.Connection) -> None:
    """Create all tables from schema.sql if they don't exist."""
    schema = SCHEMA_PATH.read_text()
    conn.executescript(schema)
    conn.commit()



if __name__ == "__main__":
    print("Connecting to database and running schema migrations...")
    try:
        # Establish connection (This automatically creates the blank .db file)
        connection = get_connection()
        init_db(connection)
        connection.close()
        
        print("Success! 'profiler.db' has been created in your data/ folder.")
        
    except FileNotFoundError as e:
        print(f"\n[ERROR] Initialization Failed: {e}")
        print("Make sure your 'data/schema.sql' file exists in the right folder location!")
    except Exception as e:
        print(f"\n[ERROR] An unexpected error occurred: {e}")
