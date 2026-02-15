import sqlite3
import os

DB_PATH = 'assets/database/breeze_jp.sqlite'

def update_audio_paths():
    if not os.path.exists(DB_PATH):
        print(f"Error: Database file not found at {DB_PATH}")
        return

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Update example_audio
        print("Updating example_audio table...")
        cursor.execute("SELECT COUNT(*) FROM example_audio WHERE audio_url LIKE '%audio/example%'")
        count_example = cursor.fetchone()[0]
        print(f"Found {count_example} rows to update in example_audio.")

        cursor.execute("""
            UPDATE example_audio 
            SET audio_url = REPLACE(audio_url, 'audio/example', 'audio/audio_examples') 
            WHERE audio_url LIKE '%audio/example%'
        """)
        print(f"Updated {cursor.rowcount} rows in example_audio.")

        # Update word_audio
        print("Updating word_audio table...")
        cursor.execute("SELECT COUNT(*) FROM word_audio WHERE audio_url LIKE '%audio/word%'")
        count_word = cursor.fetchone()[0]
        print(f"Found {count_word} rows to update in word_audio.")

        cursor.execute("""
            UPDATE word_audio 
            SET audio_url = REPLACE(audio_url, 'audio/word', 'audio/audio_words') 
            WHERE audio_url LIKE '%audio/word%'
        """)
        print(f"Updated {cursor.rowcount} rows in word_audio.")

        conn.commit()
        print("Database update committed successfully.")

    except sqlite3.Error as e:
        print(f"SQLite error: {e}")
        conn.rollback()
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    update_audio_paths()
