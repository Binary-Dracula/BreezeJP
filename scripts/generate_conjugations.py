import sqlite3
import re

DB_PATH = 'assets/database/breeze_jp.sqlite'

# Conjugation rules
# V1: Godan (u-verbs)
# V2: Ichidan (ru-verbs)
# VK: Kuru (Ka-hen)
# VS: Suru (Sa-hen)
# ADJ_I: I-adjective
# ADJ_NA: Na-adjective

def get_verb_type(word, pos):
    """
    Determine verb type from POS string and word ending.
    """
    if any(x in pos for x in ['动1', '五段']):
        return 'V1'
    elif any(x in pos for x in ['动2', '一段']):
        return 'V2'
    elif any(x in pos for x in ['动3', 'カ変', 'サ変']):
        if word.endswith('する'):
            return 'VS'
        if word.endswith('くる') or word.endswith('来る'):
            return 'VK'
        # Some nouns might be marked as suru-verbs but just noun part
        return 'VS' 
    elif 'イ形' in pos:
        return 'ADJ_I'
    elif 'ナ形' in pos:
        return 'ADJ_NA'
    return None

def conjugate_v1(word):
    """Conjugate Godan verbs."""
    # Last char mapping
    # u -> i (polite), a (negative), e (potential/imperative), o (volitional), tte/ta (te/ta form)
    
    stem = word[:-1]
    last = word[-1]
    
    # Te-form / Ta-form rules
    te_suffix = ''
    ta_suffix = ''
    
    if last in ['う', 'つ', 'る']:
        te_suffix = 'って'
        ta_suffix = 'った'
    elif last in ['ぬ', 'ぶ', 'む']:
        te_suffix = 'んで'
        ta_suffix = 'んだ'
    elif last == 'く':
        if word == '行く' or word == 'いく': # Exception
            te_suffix = 'って'
            ta_suffix = 'った'
        else:
            te_suffix = 'いて'
            ta_suffix = 'いた'
    elif last == 'ぐ':
        te_suffix = 'いで'
        ta_suffix = 'いだ'
    elif last == 'す':
        te_suffix = 'して'
        ta_suffix = 'した'
        
    # Dict to storage mappings
    forms = {}
    
    # Helper to change u-sound to i-sound
    u_to_i = {'う':'い', 'く':'き', 'ぐ':'ぎ', 'す':'し', 'つ':'ち', 'ぬ':'に', 'ぶ':'び', 'む':'み', 'る':'り'}
    u_to_a = {'う':'わ', 'く':'か', 'ぐ':'が', 'す':'さ', 'つ':'た', 'ぬ':'な', 'ぶ':'ば', 'む':'ま', 'る':'ら'}
    u_to_e = {'う':'え', 'く':'け', 'ぐ':'げ', 'す':'せ', 'つ':'て', 'ぬ':'ね', 'ぶ':'べ', 'む':'め', 'る':'れ'}
    u_to_o = {'う':'お', 'く':'こ', 'ぐ':'ご', 'す':'そ', 'つ':'と', 'ぬ':'の', 'ぶ':'ぼ', 'む':'も', 'る':'ろ'}

    i_stem = stem + u_to_i[last]
    a_stem = stem + u_to_a[last]
    e_stem = stem + u_to_e[last]
    o_stem = stem + u_to_o[last]

    forms['polite_present'] = i_stem + 'ます'
    forms['polite_past'] = i_stem + 'ました'
    forms['polite_negative'] = i_stem + 'ません'
    forms['polite_past_negative'] = i_stem + 'ませんでした'
    
    forms['plain_present'] = word
    forms['plain_past'] = stem + ta_suffix
    forms['plain_negative'] = a_stem + 'ない'
    forms['plain_past_negative'] = a_stem + 'なかった'
    
    forms['te_form'] = stem + te_suffix
    
    forms['potential'] = e_stem + 'る'
    forms['passive'] = a_stem + 'れる'
    forms['causative'] = a_stem + 'せる'
    forms['causative_passive'] = a_stem + 'せられる' # or sareru
    
    forms['imperative'] = e_stem
    forms['volitional'] = o_stem + 'う'
    
    forms['conditional_ba'] = e_stem + 'ば'
    forms['conditional_tara'] = stem + ta_suffix + 'ら'
    
    return forms

def conjugate_v2(word):
    """Conjugate Ichidan verbs (ru-verbs)."""
    stem = word[:-1] # Remove る
    
    forms = {}
    forms['polite_present'] = stem + 'ます'
    forms['polite_past'] = stem + 'ました'
    forms['polite_negative'] = stem + 'ません'
    forms['polite_past_negative'] = stem + 'ませんでした'
    
    forms['plain_present'] = word
    forms['plain_past'] = stem + 'た'
    forms['plain_negative'] = stem + 'ない'
    forms['plain_past_negative'] = stem + 'なかった'
    
    forms['te_form'] = stem + 'て'
    
    forms['potential'] = stem + 'られる'
    forms['passive'] = stem + 'られる'
    forms['causative'] = stem + 'させる'
    forms['causative_passive'] = stem + 'させられる'
    
    forms['imperative'] = stem + 'ろ'
    forms['volitional'] = stem + 'よう'
    
    forms['conditional_ba'] = stem + 'れば'
    forms['conditional_tara'] = stem + 'たら'
    
    return forms

def conjugate_vs(word):
    """Conjugate Suru verbs."""
    # Often noun + suru
    if word == 'する':
        prefix = ''
    elif word.endswith('する'):
        prefix = word[:-2]
    else:
        # Assuming it's a noun that acts as VS, append suru
        prefix = word
    
    forms = {}
    forms['polite_present'] = prefix + 'します'
    forms['polite_past'] = prefix + 'しました'
    forms['polite_negative'] = prefix + 'しません'
    forms['polite_past_negative'] = prefix + 'しませんでした'
    
    forms['plain_present'] = prefix + 'する'
    forms['plain_past'] = prefix + 'した'
    forms['plain_negative'] = prefix + 'しない'
    forms['plain_past_negative'] = prefix + 'しなかった'
    
    forms['te_form'] = prefix + 'して'
    
    forms['potential'] = prefix + 'できる' # proper potential is dekiru
    forms['passive'] = prefix + 'される'
    forms['causative'] = prefix + 'させる'
    forms['causative_passive'] = prefix + 'させられる'
    
    forms['imperative'] = prefix + 'しろ'
    forms['volitional'] = prefix + 'しよう'
    
    forms['conditional_ba'] = prefix + 'すれば'
    forms['conditional_tara'] = prefix + 'したら'
    
    return forms

def conjugate_vk(word):
    """Conjugate Kuru verbs."""
    # Comes as 来る or くる usually
    # Handling irregular kanji readings is tricky without furigana context
    # But usually output is standard
    
    # If word is kanji '来る', we output kanji forms? 
    # Or just kana? Usually kana is safer for conjugation rules unless we have furigana.
    # Let's support '来る' specifically.
    
    is_kanji = '来' in word
    
    forms = {}
    
    if is_kanji:
        # Standard readings: 
        # kimasu (来ます), kita (来た), konai (来ない), kuru (来る)
        forms['polite_present'] = '来ます'
        forms['polite_past'] = '来ました'
        forms['polite_negative'] = '来ません'
        forms['polite_past_negative'] = '来ませんでした'
        
        forms['plain_present'] = '来る'
        forms['plain_past'] = '来た'
        forms['plain_negative'] = '来ない' # konai
        forms['plain_past_negative'] = '来なかった'
        
        forms['te_form'] = '来て'
        
        forms['potential'] = '来られる' # korareru
        forms['passive'] = '来られる'
        forms['causative'] = '来させる' # kosaseru
        forms['causative_passive'] = '来させられる'
        
        forms['imperative'] = '来い' # koi
        forms['volitional'] = '来よう' # koyou
        
        forms['conditional_ba'] = '来れば' # kureba
        forms['conditional_tara'] = '来たら'
    else:
        forms['polite_present'] = 'きます'
        forms['polite_past'] = 'きました'
        forms['polite_negative'] = 'きません'
        forms['polite_past_negative'] = 'きませんでした'
        
        forms['plain_present'] = 'くる'
        forms['plain_past'] = 'きた'
        forms['plain_negative'] = 'こない'
        forms['plain_past_negative'] = 'こなかった'
        
        forms['te_form'] = 'きて'
        
        forms['potential'] = 'こられる'
        forms['passive'] = 'こられる'
        forms['causative'] = 'こさせる'
        forms['causative_passive'] = 'こさせられる'
        
        forms['imperative'] = 'こい'
        forms['volitional'] = 'こよう'
        
        forms['conditional_ba'] = 'くれば'
        forms['conditional_tara'] = 'きたら'

    return forms

def conjugate_adj_i(word):
    """Conjugate I-adjectives."""
    if word == 'いい': # Exception
        stem = 'よ'
        base = 'い' # kind of
        # Special handling for 'ii'
        forms = {}
        forms['polite_present'] = 'いいです'
        forms['polite_past'] = 'よかったです'
        forms['polite_negative'] = 'よくないです' # or yoku-arimasen
        forms['polite_past_negative'] = 'よくなかったです'
        
        forms['plain_present'] = 'いい'
        forms['plain_past'] = 'よかった'
        forms['plain_negative'] = 'よくない'
        forms['plain_past_negative'] = 'よくなかった'
        forms['te_form'] = 'よくて'
        forms['conditional_ba'] = 'よければ'
        forms['conditional_tara'] = 'よかったら'
        return forms
        
    stem = word[:-1]
    
    forms = {}
    forms['polite_present'] = word + 'です'
    forms['polite_past'] = stem + 'かったです'
    forms['polite_negative'] = stem + 'くないです'
    forms['polite_past_negative'] = stem + 'くなかったです'
    
    forms['plain_present'] = word
    forms['plain_past'] = stem + 'かった'
    forms['plain_negative'] = stem + 'くない'
    forms['plain_past_negative'] = stem + 'くなかった'
    
    forms['te_form'] = stem + 'くて'
    
    forms['conditional_ba'] = stem + 'ければ'
    forms['conditional_tara'] = stem + 'かったら'
    
    # Adjectives don't have potential/passive etc usually.
    return forms

def conjugate_adj_na(word):
    """Conjugate Na-adjectives."""
    # Word usually comes as stem only in many DBs, or stem+na?
    # Checking existing DB might be needed. Usually stored as stem (e.g. 綺麗 without na)
    # But checking POS 'ナ形'.
    
    stem = word # Assuming stored as stem
    
    forms = {}
    forms['polite_present'] = stem + 'です'
    forms['polite_past'] = stem + 'でした'
    forms['polite_negative'] = stem + 'じゃないです' # or dewa-arimasen
    forms['polite_past_negative'] = stem + 'じゃなかったです'
    
    forms['plain_present'] = stem + 'だ'
    forms['plain_past'] = stem + 'だった'
    forms['plain_negative'] = stem + 'じゃない' # or dewa-nai
    forms['plain_past_negative'] = stem + 'じゃなかった'
    
    forms['te_form'] = stem + 'で'
    
    forms['conditional_ba'] = stem + 'ならば' # or nara
    forms['conditional_tara'] = stem + 'だったら'
    
    return forms

def get_conjugations(word, pos):
    vtype = get_verb_type(word, pos)
    if not vtype:
        return None
        
    if vtype == 'V1':
        return conjugate_v1(word)
    elif vtype == 'V2':
        return conjugate_v2(word)
    elif vtype == 'VS':
        return conjugate_vs(word)
    elif vtype == 'VK':
        return conjugate_vk(word)
    elif vtype == 'ADJ_I':
        return conjugate_adj_i(word)
    elif vtype == 'ADJ_NA':
        return conjugate_adj_na(word)
    return None

def init_types(cursor):
    """Initialize conjugation types in the database."""
    types = [
        ('polite_present', 'ます形', '敬体-非过去', 10, 'Polite non-past form'),
        ('polite_past', 'ました形', '敬体-过去', 20, 'Polite past form'),
        ('polite_negative', 'ません形', '敬体-否定', 30, 'Polite negative form'),
        ('polite_past_negative', 'ませんでした形', '敬体-过去否定', 40, 'Polite past negative form'),
        ('plain_present', '辞書形', '简体-非过去', 50, 'Plain non-past form (Dictionary form)'),
        ('plain_past', 'た形', '简体-过去', 60, 'Plain past form (Ta-form)'),
        ('plain_negative', 'ない形', '简体-否定', 70, 'Plain negative form (Nai-form)'),
        ('plain_past_negative', 'なかった形', '简体-过去否定', 80, 'Plain past negative form'),
        ('te_form', 'て形', '连接形 (て形)', 90, 'Te-form, used for connecting sentences'),
        ('potential', '可能形', '可能态', 100, 'Potential form (can do)'),
        ('passive', '受身形', '被动态', 110, 'Passive form'),
        ('causative', '使役形', '使役态', 120, 'Causative form (make/let someone do)'),
        ('causative_passive', '使役受身形', '使役被动', 130, 'Causative-passive form'),
        ('imperative', '命令形', '命令形', 140, 'Imperative form'),
        ('volitional', '意向形', '意向形', 150, 'Volitional form (let\'s do)'),
        ('conditional_ba', 'ば形', '假定形 (ば)', 160, 'Conditional form (if)'),
        ('conditional_tara', 'たら形', '假定形 (たら)', 170, 'Conditional form (when/if)'),
    ]

    print("Initializing conjugation types...")
    for code, name_ja, name_cn, sort_order, desc in types:
        cursor.execute('''
            INSERT OR IGNORE INTO conjugation_types (code, name_ja, name_cn, sort_order, description)
            VALUES (?, ?, ?, ?, ?)
        ''', (code, name_ja, name_cn, sort_order, desc))

def get_type_map(cursor):
    cursor.execute("SELECT code, id FROM conjugation_types")
    return {row[0]: row[1] for row in cursor.fetchall()}

def main():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Enable FK support just in case
    cursor.execute("PRAGMA foreign_keys = ON;")
    
    init_types(cursor)
    conn.commit()
    
    type_map = get_type_map(cursor)
    
    print("Fetching words...")
    cursor.execute("SELECT id, word, part_of_speech, furigana FROM words WHERE part_of_speech LIKE '%动%' OR part_of_speech LIKE '%形%'")
    words = cursor.fetchall()
    print(f"Found {len(words)} candidates.")
    
    count = 0
    skipped = 0
    
    for word_id, word, pos, furigana in words:
        conjugations = get_conjugations(word, pos)
        if not conjugations:
            skipped += 1
            continue
            
        for type_code, conjugated_word in conjugations.items():
            if type_code not in type_map:
                continue
                
            type_id = type_map[type_code]
            
            try:
                cursor.execute('''
                    INSERT OR REPLACE INTO word_conjugations (word_id, type_id, conjugated_word)
                    VALUES (?, ?, ?)
                ''', (word_id, type_id, conjugated_word))
            except sqlite3.Error as e:
                print(f"Error inserting {word} ({type_code}): {e}")
        
        count += 1
        if count % 100 == 0:
            print(f"Processed {count} words...")

    conn.commit()
    conn.close()
    print(f"Done. Processed {count} words. Skipped {skipped}.")

if __name__ == "__main__":
    main()
