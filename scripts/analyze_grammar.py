import sqlite3
import os
import collections

# Path to the database
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'database', 'breeze_jp.sqlite')

def is_grammar(part_of_speech):
    if part_of_speech is None:
        return False
    grammar_types = [
        '成句',
        '連語',
        '接',
        '助詞', '副助', '接助', '終助',
        '助動詞', '補動',
        '接頭', '接尾', '造',
        '形動トタル'
    ]
    # Check if any grammar type is in part_of_speech
    return any(g in part_of_speech for g in grammar_types)

def analyze_grammar():
    if not os.path.exists(DB_PATH):
        print(f"Error: Database not found at {DB_PATH}")
        return

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, word, part_of_speech, jlpt_level FROM words")
        rows = cursor.fetchall()
        
        total_count = len(rows)
        grammar_count = 0
        word_count = 0
        
        grammar_examples = []
        word_examples = []
        
        # Define categories
        categories = {
            'Prefix/Suffix': ['接頭', '接尾', '造'],
            'Conjunction': ['接', '接助', '順接'],
            'Particle': ['助詞', '副助', '終助'],
            'Compound/Phrase': ['連語', '成句'],
            'Auxiliary Verb': ['助動詞', '補動'],
            'Adjectival Verb': ['形動トタル'],
        }
        
        category_counts = collections.defaultdict(int)
        
        # Breakdown by specific grammar type found
        grammar_breakdown = collections.Counter()

        for row in rows:
            word_id, word, pos, level = row
            
            if pos and is_grammar(pos):
                grammar_count += 1
                if len(grammar_examples) < 10:
                    grammar_examples.append(f"{word} ({pos})")
                
                # Categorize
                matched_category = 'Other'
                for cat_name, keywords in categories.items():
                    if any(k in pos for k in keywords):
                        matched_category = cat_name
                        break
                category_counts[matched_category] += 1
                
                grammar_breakdown[pos] += 1
            else:
                word_count += 1
                if len(word_examples) < 10:
                    word_examples.append(f"{word} ({pos})")

        print("-" * 40)
        print(f"Total Entries: {total_count}")
        print(f"Grammar Entries: {grammar_count} ({grammar_count/total_count*100:.2f}%)")
        print(f"Word Entries: {word_count} ({word_count/total_count*100:.2f}%)")
        print("-" * 40)
        
        print("\nGrammar Frequency by Category:")
        for cat, count in sorted(category_counts.items(), key=lambda x: x[1], reverse=True):
             print(f" - {cat}: {count}")

        print("\nDetailed POS Breakdown (Top 20):")
        for pos, count in grammar_breakdown.most_common(20):
            print(f" - {pos}: {count}")

        conn.close()
        
    except sqlite3.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    analyze_grammar()
