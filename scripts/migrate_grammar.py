import sqlite3
import os
import shutil
import time
import argparse

# Path to the database
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'database', 'breeze_jp.sqlite')
BACKUP_DIR = os.path.join(os.path.dirname(DB_PATH), 'backups')

def ensure_backup_dir():
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)

def create_backup():
    ensure_backup_dir()
    timestamp = int(time.time())
    backup_path = os.path.join(BACKUP_DIR, f'breeze_jp_migration_backup_{timestamp}.sqlite')
    shutil.copy2(DB_PATH, backup_path)
    print(f"Database backed up to: {backup_path}")
    return backup_path

def migrate_db(dry_run=False):
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    if not dry_run:
        create_backup()

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        print("Starting Database Restructuring...")

        # 1. Create New Tables
        print("Creating new tables...")
        cursor.executescript("""
        CREATE TABLE IF NOT EXISTS grammars (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            meaning TEXT,
            connection TEXT,
            jlpt_level TEXT,
            tags TEXT,
            created_at INTEGER,
            updated_at INTEGER
        );

        CREATE TABLE IF NOT EXISTS grammar_examples (
            id INTEGER PRIMARY KEY,
            grammar_id INTEGER NOT NULL,
            sentence TEXT,
            translation TEXT,
            audio_url TEXT,
            created_at INTEGER,
            FOREIGN KEY(grammar_id) REFERENCES grammars(id)
        );

        CREATE TABLE IF NOT EXISTS study_grammars (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            grammar_id INTEGER NOT NULL,
            learning_status INTEGER DEFAULT 0,
            next_review_at INTEGER,
            last_reviewed_at INTEGER,
            interval REAL DEFAULT 0,
            ease_factor REAL DEFAULT 2.5,
            stability REAL DEFAULT 0,
            difficulty REAL DEFAULT 0,
            streak INTEGER DEFAULT 0,
            total_reviews INTEGER DEFAULT 0,
            fail_count INTEGER DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER,
            UNIQUE(user_id, grammar_id),
            FOREIGN KEY(grammar_id) REFERENCES grammars(id)
        );
        """)

        # 2. Identify Grammar Entries
        # Keywords based on calibration
        grammar_keywords = [
            '接続詞', '助動詞', '助詞', '連語', '成句', '文法', 
            '接頭', '接尾', '接辞', '造'
        ]
        
        # Construct the LIKE clause
        like_clauses = " OR ".join([f"part_of_speech LIKE '%{k}%'" for k in grammar_keywords])
        
        select_sql = f"""
            SELECT id, word, part_of_speech, jlpt_level 
            FROM words 
            WHERE {like_clauses}
        """
        
        cursor.execute(select_sql)
        grammar_rows = cursor.fetchall()
        print(f"Identified {len(grammar_rows)} grammar entries to migrate.")

        if dry_run:
            print("[Dry Run] Would migrate the following sample entries:")
            for row in grammar_rows[:5]:
                print(f" - {row[1]} ({row[2]})")
            conn.close()
            return

        # 3. Migrate Data
        count = 0
        for row in grammar_rows:
            w_id, w_word, w_pos, w_level = row
            
            # Get Meaning
            cursor.execute("SELECT meaning_cn FROM word_meanings WHERE word_id = ? ORDER BY definition_order LIMIT 1", (w_id,))
            meaning_row = cursor.fetchone()
            meaning = meaning_row[0] if meaning_row else None
            
            # Insert into grammars
            # We keep the ID same as word_id to make related data migration easier, assuming no conflict in new table
            cursor.execute("""
                INSERT INTO grammars (id, title, meaning, connection, jlpt_level, tags, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, strftime('%s', 'now'), strftime('%s', 'now'))
            """, (w_id, w_word, meaning, '', w_level, w_pos))
            
            # Migrate Examples
            cursor.execute("""
                INSERT INTO grammar_examples (id, grammar_id, sentence, translation, audio_url, created_at)
                SELECT id, word_id, sentence_jp, translation_cn, NULL, strftime('%s', 'now')
                FROM example_sentences
                WHERE word_id = ?
            """, (w_id,))

            count += 1

        print(f"Migrated {count} entries to 'grammars' and 'grammar_examples'.")

        # 4. Cleanup Old Data
        print("Cleaning up old data from 'words' ecosystem...")
        
        # We need the IDs again or just use the same condition? 
        # Safer to use the IDs we identified to ensure exactly what we moved is deleted.
        grammar_ids = [str(r[0]) for r in grammar_rows]
        if grammar_ids:
            ids_str = ",".join(grammar_ids)
            
            # Delete from study_words (Legacy user data - Ignoring as requested)
            cursor.execute(f"DELETE FROM study_words WHERE word_id IN ({ids_str})")
            print(f"Deleted study_words records.")

            # Delete from example_sentences
            cursor.execute(f"DELETE FROM example_sentences WHERE word_id IN ({ids_str})")
            print(f"Deleted example_sentences records.")

            # Delete from word_meanings
            cursor.execute(f"DELETE FROM word_meanings WHERE word_id IN ({ids_str})")
            print(f"Deleted word_meanings records.")

            # Delete from words
            cursor.execute(f"DELETE FROM words WHERE id IN ({ids_str})")
            print(f"Deleted words records.")

        conn.commit()
        print("Restructuring Complete.")

    except Exception as e:
        print(f"Error during migration: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Restructure database: Split Grammar from Words')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without modifying DB')
    args = parser.parse_args()
    
    migrate_db(dry_run=args.dry_run)
