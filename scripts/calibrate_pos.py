import sqlite3
import MeCab
import os
import shutil
import time
import argparse
from jamdict import Jamdict

# Path to the database
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'database', 'breeze_jp.sqlite')
BACKUP_DIR = os.path.join(os.path.dirname(DB_PATH), 'backups')

def ensure_backup_dir():
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)

def create_backup():
    ensure_backup_dir()
    timestamp = int(time.time())
    backup_path = os.path.join(BACKUP_DIR, f'breeze_jp_backup_{timestamp}.sqlite')
    shutil.copy2(DB_PATH, backup_path)
    print(f"Database backed up to: {backup_path}")
    return backup_path

def rollback(backup_path):
    if not os.path.exists(backup_path):
        print(f"Backup file not found: {backup_path}")
        return
    
    # Close any connections if possible (not needed here as we open/close in functions)
    shutil.copy2(backup_path, DB_PATH)
    print(f"Database restored from: {backup_path}")

def get_latest_backup():
    ensure_backup_dir()
    files = [os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR) if f.endswith('.sqlite')]
    if not files:
        return None
    return max(files, key=os.path.getctime)

def analyze_and_update(dry_run=False):
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    # Create backup before modifying
    if not dry_run:
        create_backup()

    try:
        tagger = MeCab.Tagger()
        jam = Jamdict() # Initialize Jamdict
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, word, part_of_speech FROM words")
        rows = cursor.fetchall()
        
        updates = []
        
        print("Analyzing vocab...")
        
        for row in rows:
            word_id, word, current_pos = row
            
            # Remove leading/trailing tilde for analysis if present, but keep original for context
            clean_word = word.replace('〜', '').replace('~', '')
            if not clean_word: continue

            node = tagger.parseToNode(clean_word)
            
            # Simple heuristic: Check the POS of the first meaningful node or the whole structure
            # MeCab POS format in unidic: pos1,pos2,pos3,pos4
            
            new_pos = current_pos
            is_grammar = False
            
            # Heuristics based on keyword presence (stronger than generic MeCab sometimes for JLPT grammar)
            if '〜' in word:
                 # Likely a suffix, prefix, or grammar point
                 pass
            
            while node:
                features = node.feature.split(',')
                pos1 = features[0]
                pos2 = features[1] if len(features) > 1 else ''
                
                # Check for particles, auxiliary verbs, etc.
                if pos1 in ['助詞', '助動詞', '接頭辞', '接尾辞', '連体詞']:
                     # If the word is *essentially* just this, or a compound of these
                     # We might want to tag it. 
                     # For now, let's just log what MeCab thinks vs what we have.
                     pass
                
                node = node.next

            # NOTE: MeCab is good for tokenizing sentences. For single vocabulary words, 
            # sometimes the dictionary definition is better.
            # However, if we want to detect "Grammar", we look for:
            # 1. Words containing '〜' -> Label as 'Phrase/Grammar' or specific parts
            # 2. Existing '連語', '成句' tags are good.
            # 3. Use MeCab to identify 'Particle' (助詞) or 'Auxiliary Verb' (助動詞) if not tagged.

            # Heuristic application:
            detected_type = None
            
            # 1. Explicit symbols
            if '〜' in word:
                if word.startswith('〜') and word.endswith('〜'): detected_type = 'Middle Phrase' # Rare
                elif word.startswith('〜'): detected_type = '接尾/Suffix' # or Grammar
                elif word.endswith('〜'): detected_type = '接頭/Prefix'
                else: detected_type = '文法/Grammar' # Middle like ...〜...

            # 2. Jamdict Analysis (Secondary Check)
            # Only if MeCab didn't give a strong signal or to confirm
            try:
                # Jamdict might be slow if initialized every time, moved outside loop
                j_result = jam.lookup(word)
                if j_result.entries:
                    # Check the first few entries/senses
                    for entry in j_result.entries[:2]:
                        for sense in entry.senses:
                            # suble is a list of POS strings in Jamdict
                            # e.g. 'exp' (Expressions), 'prt' (Particle), 'aux' (Auxiliary)
                            # 'conj' (Conjunction), 'pref' (Prefix), 'suf' (Suffix)
                            parts = [str(x) for x in sense.pos] 
                            
                            if 'exp' in parts or 'int' in parts: # Expressions often grammar
                                if not detected_type: detected_type = '文法/Grammar'
                            if 'prt' in parts:
                                detected_type = '助詞/Particle'
                            if 'aux' in parts or 'aux-v' in parts or 'aux-adj' in parts:
                                detected_type = '助動詞/Aux'
                            if 'conj' in parts:
                                detected_type = '接続詞/Conjunction'
                            if 'pref' in parts:
                                detected_type = '接頭/Prefix'
                            if 'suf' in parts:
                                detected_type = '接尾/Suffix'
                            
                            if detected_type: break
                        if detected_type: break
            except Exception as e:
                # print(f"Jamdict error for {word}: {e}")
                pass

            # 3. MeCab Analysis (Fallback or Refinement)
            if not detected_type:
                # Re-parse
                node = tagger.parseToNode(clean_word)
                
                # Analyze the first node
                first_node_feature = node.next.feature.split(',') if node.next else []
                pos1 = first_node_feature[0] if first_node_feature else ''

                if pos1 == '助詞': 
                    detected_type = '助詞/Particle'
                elif pos1 == '助動詞': 
                    detected_type = '助動詞/Aux'
                elif pos1 == '接続詞': 
                    detected_type = '接続詞/Conjunction'
                elif pos1 == '連体詞': 
                    detected_type = '連体詞/Determiner'
                
                # Careful with Prefixes/Suffixes
                elif pos1 == '接頭辞' and ('〜' in word or len(clean_word) == 1):
                    detected_type = '接頭/Prefix'
                elif pos1 == '接尾辞' and ('〜' in word): 
                    detected_type = '接尾/Suffix'

            # Determine if we should update
            should_update = False
            proposed_pos = current_pos

            if detected_type:
                grammar_type_label = detected_type.split('/')[-1] # e.g. 'Particle'
                grammar_kanji = detected_type.split('/')[0]      # e.g. '助詞'

                # Case 1: Current POS is empty
                if not current_pos:
                    proposed_pos = grammar_kanji
                    should_update = True
                
                # Case 2: Replace abbreviations or Append if missing
                elif grammar_kanji not in current_pos:
                     
                     # Define abbreviation mappings (Full -> [Abbreviations])
                     abbreviations = {
                         '接続詞': ['接'],
                         '連体詞': ['連体'],
                         '副詞': ['副'],
                         '接頭辞': ['接頭'], # Standardize if needed
                         '接尾辞': ['接尾'],
                         '助詞': ['助'],
                     }
                     
                     target_abbrs = abbreviations.get(grammar_kanji, [])
                     
                     parts = current_pos.split('・')
                     new_parts = []
                     replaced = False
                     
                     for p in parts:
                         if p in target_abbrs:
                             new_parts.append(grammar_kanji)
                             replaced = True
                         else:
                             new_parts.append(p)
                     
                     # If we didn't find an abbreviation to replace, we append the new term
                     # UNLESS it's already there (checked by elif above)
                     if not replaced:
                         new_parts.append(grammar_kanji)
                     
                     proposed_pos = '・'.join(new_parts)
                     should_update = True
            
            # Special Case: '〜' implies grammar/affix usually. 
            if '〜' in word and not should_update:
                 if '接' not in (current_pos or '') and '造' not in (current_pos or ''):
                     proposed_pos = (current_pos + '・' if current_pos else '') + '接辞/Affix'
                     should_update = True

            if should_update:
                updates.append((proposed_pos, word_id, word, current_pos))

        print(f"Found {len(updates)} candidates for update.")
        
        if dry_run:
            print("DRY RUN. No changes made. Sample proposed changes:")
            for i, (new, wid, w, old) in enumerate(updates[:20]):
                print(f"[{wid}] {w}: '{old}' -> '{new}'")
        else:
            print("Applying updates...")
            count = 0
            for new_pos, wid, w, old in updates:
                cursor.execute("UPDATE words SET part_of_speech = ? WHERE id = ?", (new_pos, wid))
                count += 1
            conn.commit()
            print(f"Updated {count} records.")

        conn.close()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Calibrate database POS using MeCab')
    parser.add_argument('--rollback', action='store_true', help='Rollback to the latest backup')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without modifying DB')
    
    args = parser.parse_args()
    
    if args.rollback:
        latest = get_latest_backup()
        if latest:
            rollback(latest)
        else:
            print("No backup found.")
    else:
        analyze_and_update(dry_run=args.dry_run)
