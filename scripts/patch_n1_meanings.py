#!/usr/bin/env python3
"""修正 N1 中 7 条 meaning 为空的语法条目（用户手动整理）"""
import sqlite3

DB_PATH = "assets/database/breeze_jp.sqlite"

conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

def get_mid(gid, sort=1):
    c.execute("SELECT id FROM grammar_meanings WHERE grammar_id=? AND sort_order=?", (gid, sort))
    r = c.fetchone()
    return r[0] if r else None

# === #1 (gid=537) ~はいざしらず ===
mid = get_mid(537, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
          ("名＋はいざしらず（ならいざしらず）",
           "……另当别论，可是……", mid))
# tip already exists, keep it
print("  \u2705 #537 ~はいざしらず: meaning + connection")

# === #2 (gid=557) ~からとて ===
mid = get_mid(557, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=?, tip=? WHERE id=?",
          ("普通体＋からとて～ない",
           "就算是……也不能……",
           "后项不能因为前项的理由而成立。后项为部分否定的句子。书面语。",
           mid))
print("  \u2705 #557 ~からとて: meaning + connection + tip")

# === #3 (gid=602) ~なりに / なりの ===
mid = get_mid(602, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
          ("名/ナ-だ/イ-い/动-る/活用词-た＋なりに（なりの）",
           "与……相应", mid))
# tip already exists, keep it
print("  \u2705 #602 ~なりに: meaning + connection")

# === #4 (gid=609) ~に至っては — 2 meanings ===
# 义项1
mid1 = get_mid(609, 1)
c.execute("UPDATE grammar_meanings SET meaning=?, tip=? WHERE id=?",
          ("至于……",
           "提示极端例子，并加以消极性的评价", mid1))
print("  \u2705 #609 ~に至っては 义项1: meaning + tip")

# 义项2 - already has meaning, add tip
mid2 = get_mid(609, 2)
c.execute("UPDATE grammar_meanings SET meaning=?, tip=? WHERE id=?",
          ("时至今日已经……",
           '用于"事情既然已经发展到了这般地步，已经无计可施"的场合。'
           '多以「どうしようもない/どうにもならない/どうすることもできない」等表示无计可施意思的句子结句。'
           '其中「ことここに至っては/これまでに至っては」为惯用形式。',
           mid2))
print("  \u2705 #609 ~に至っては 义项2: meaning + tip")

# === #5 (gid=617) ~だに — 2 meanings ===
# 义项1 - already has meaning, keep it
# 义项2
mid2 = get_mid(617, 2)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
          ("（2）名（＋助词）/动-る＋だに～ない",
           "完全不……", mid2))
# tip already exists, keep it
print("  \u2705 #617 ~だに 义项2: meaning + connection")

# === #6 (gid=644) ~てもさしつかえない ===
mid = get_mid(644, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
          ("名-で/ナ-で/イ-て/动-て＋もさしつかえない",
           "即使……也无妨", mid))
# tip already exists, keep it
print("  \u2705 #644 ~てもさしつかえない: meaning + connection")

# === #7 (gid=645) ~てかなわない / てやりきれない ===
mid = get_mid(645, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
          ("ナ-で/イ-て/动-て＋かなわない（やりきれない）",
           "……得不得了", mid))
# tip already exists, keep it
print("  \u2705 #645 ~てかなわない: meaning + connection")

conn.commit()

# Verify
c.execute('''SELECT COUNT(*) FROM grammar_meanings m JOIN grammars g ON g.id=m.grammar_id
             WHERE g.jlpt_level='N1' AND m.meaning IS NULL''')
print(f"\nN1 meaning为空: {c.fetchone()[0]} 条")
conn.close()
print("全部修正完成!")
