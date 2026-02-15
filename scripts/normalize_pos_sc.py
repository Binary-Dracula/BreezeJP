
import sqlite3

DB_PATH = 'assets/database/breeze_jp.sqlite'

def normalize_pos():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    replacements = {
        '動': '动',
        '連': '连',
        '詞': '词',
        '補': '补',
        '終': '终'
    }
    
    print("Checking for Japanese characters in part_of_speech...")
    # Find rows matching checking any of the keys
    conditions = " OR ".join([f"part_of_speech LIKE '%{k}%'" for k in replacements.keys()])
    cursor.execute(f"SELECT id, word, part_of_speech FROM words WHERE {conditions}")
    rows = cursor.fetchall()
    
    if not rows:
        print("No entries found with specified Japanese characters.")
        conn.close()
        return

    print(f"Found {len(rows)} entries to normalize.")
    
    count = 0
    for word_id, word, pos in rows:
        new_pos = pos
        for k, v in replacements.items():
            new_pos = new_pos.replace(k, v)
            
        if new_pos != pos:
            cursor.execute("UPDATE words SET part_of_speech = ? WHERE id = ?", (new_pos, word_id))
            count += 1
            # print(f"Updated {word}: {pos} -> {new_pos}")
            
    conn.commit()
    conn.close()
    print(f"Normalized {count} entries.")

if __name__ == "__main__":
    normalize_pos()
