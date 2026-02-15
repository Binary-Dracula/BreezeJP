
import sqlite3

DB_PATH = 'assets/database/breeze_jp.sqlite'

def normalize_pos():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    print("Checking for '动' in part_of_speech...")
    cursor.execute("SELECT id, word, part_of_speech FROM words WHERE part_of_speech LIKE '%动%'")
    rows = cursor.fetchall()
    
    if not rows:
        print("No entries found with '动'.")
        conn.close()
        return

    print(f"Found {len(rows)} entries to normalize.")
    
    count = 0
    for word_id, word, pos in rows:
        new_pos = pos.replace('动', '動')
        if new_pos != pos:
            cursor.execute("UPDATE words SET part_of_speech = ? WHERE id = ?", (new_pos, word_id))
            count += 1
            print(f"Updated {word}: {pos} -> {new_pos}")
            
    conn.commit()
    conn.close()
    print(f"Normalized {count} entries.")

if __name__ == "__main__":
    normalize_pos()
