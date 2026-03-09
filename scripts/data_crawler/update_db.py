import sqlite3
import json
import os
import time

DB_PATH = '../../assets/database/breeze_jp.sqlite'
DATA_PATH = 'raw_grammar_data.json'

def init_db(conn):
    cursor = conn.cursor()
    
    # 1. Drop existing target tables
    cursor.execute("DROP TABLE IF EXISTS study_grammars;")
    cursor.execute("DROP TABLE IF EXISTS grammar_examples;")
    cursor.execute("DROP TABLE IF EXISTS grammar_contexts;")
    cursor.execute("DROP TABLE IF EXISTS grammar_meanings;")
    cursor.execute("DROP TABLE IF EXISTS grammars;")
    
    # 2. Create `grammars` table
    cursor.execute("""
        CREATE TABLE grammars (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            jlpt_level TEXT,
            usage_frequency INTEGER DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER
        );
    """)
    
    # 3. Create `grammar_meanings` table
    cursor.execute("""
        CREATE TABLE grammar_meanings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id INTEGER NOT NULL REFERENCES grammars(id),
            sort_order INTEGER DEFAULT 1,
            definition_cn TEXT,
            definition_en TEXT,
            how_to_use_cn TEXT,
            how_to_use_en TEXT
        );
    """)
    
    # 4. Create `grammar_contexts` table
    cursor.execute("""
        CREATE TABLE grammar_contexts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id INTEGER NOT NULL REFERENCES grammars(id),
            when_to_use_cn TEXT,
            when_to_use_en TEXT
        );
    """)
    
    # 5. Create `grammar_examples` table
    # Uses `japanese_ruby` as `sentence` if it exists, fallback to `japanese`
    cursor.execute("""
        CREATE TABLE grammar_examples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id INTEGER NOT NULL REFERENCES grammars(id),
            sort_order INTEGER DEFAULT 1,
            sentence TEXT,
            translation_cn TEXT,
            translation_en TEXT,
            audio_url TEXT
        );
    """)
    
    # 6. Create `study_grammars` table
    cursor.execute("""
        CREATE TABLE study_grammars (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            grammar_id INTEGER NOT NULL REFERENCES grammars(id),
            learning_status INTEGER DEFAULT 0,
            next_review_at INTEGER,
            last_reviewed_at INTEGER,
            streak INTEGER DEFAULT 0,
            total_reviews INTEGER DEFAULT 0,
            fail_count INTEGER DEFAULT 0,
            interval REAL DEFAULT 0,
            ease_factor REAL DEFAULT 2.5,
            stability REAL DEFAULT 0,
            difficulty REAL DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER,
            UNIQUE(user_id, grammar_id)
        );
    """)
    
    conn.commit()

def import_data(conn):
    if not os.path.exists(DATA_PATH):
        print(f"Error: {DATA_PATH} not found.")
        return

    with open(DATA_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    cursor = conn.cursor()
    
    now = int(time.time())
    
    grammar_count = 0
    meaning_count = 0
    context_count = 0
    example_count = 0
    
    for item in data:
        title = item.get('grammar', '')
        if not title:
            continue
            
        level = item.get('level', '')
        usage_freq = 0 # Default since we dropped the tag fetching mapping directly to frequency if no numeric provided.
        
        # Insert grammars
        cursor.execute("""
            INSERT INTO grammars (title, jlpt_level, usage_frequency, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
        """, (title, level, usage_freq, now, now))
        
        grammar_id = cursor.lastrowid
        grammar_count += 1
        
        # Insert meaning
        def _to_str(val):
            if isinstance(val, (dict, list)):
                return json.dumps(val, ensure_ascii=False)
            return str(val) if val is not None else ''

        def_cn = _to_str(item.get('definition_cn'))
        def_en = _to_str(item.get('definition_en'))
        use_cn = _to_str(item.get('how_to_use_cn'))
        use_en = _to_str(item.get('how_to_use_en'))
        
        if def_cn or def_en or use_cn or use_en:
            cursor.execute("""
                INSERT INTO grammar_meanings (grammar_id, sort_order, definition_cn, definition_en, how_to_use_cn, how_to_use_en)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (grammar_id, 1, def_cn, def_en, use_cn, use_en))
            meaning_count += 1
            
        # Insert context
        when_cn = _to_str(item.get('context_cn'))
        when_en = _to_str(item.get('context_en'))
        
        if when_cn or when_en:
            cursor.execute("""
                INSERT INTO grammar_contexts (grammar_id, when_to_use_cn, when_to_use_en)
                VALUES (?, ?, ?)
            """, (grammar_id, when_cn, when_en))
            context_count += 1
            
        # Insert examples
        examples = item.get('examples', [])
        for i, ex in enumerate(examples):
            # Prefer ruby annotation, otherwise raw japanese
            sentence = ex.get('japanese_ruby') or ex.get('japanese', '')
            trans_cn = ex.get('chinese', '')
            trans_en = ex.get('english', '')
            
            cursor.execute("""
                INSERT INTO grammar_examples (grammar_id, sort_order, sentence, translation_cn, translation_en)
                VALUES (?, ?, ?, ?, ?)
            """, (grammar_id, i + 1, sentence, trans_cn, trans_en))
            example_count += 1

    conn.commit()
    print(f"Migration completed:")
    print(f"- Grammars: {grammar_count}")
    print(f"- Meanings: {meaning_count}")
    print(f"- Contexts: {context_count}")
    print(f"- Examples: {example_count}")
    print(f"Data has been fully replaced in {DB_PATH}.")

def main():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}. Exiting.")
        return
        
    print(f"Connecting to database {DB_PATH}...")
    conn = sqlite3.connect(DB_PATH)
    
    print("Rebuilding Schema...")
    init_db(conn)
    
    print("Importing JSON Data...")
    import_data(conn)
    
    conn.close()

if __name__ == "__main__":
    main()
