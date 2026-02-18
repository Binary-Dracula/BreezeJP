#!/usr/bin/env python3
"""修正 N2 中 10 条 meaning 为空的语法条目"""
import sqlite3

DB_PATH = "assets/database/breeze_jp.sqlite"

conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

def get_mid(gid, sort=1):
    c.execute("SELECT id FROM grammar_meanings WHERE grammar_id=? AND sort_order=?", (gid, sort))
    r = c.fetchone()
    return r[0] if r else None

# (grammar_id, sort_order, connection, meaning, tip_or_None)
patches = [
    (316, 1,
     "名＋において（は）/ においても / においての / における",
     "在……",
     None),
    (328, 1,
     "名＋にわたり（にわたって、にわたる、にわたった）",
     "长达……；多达……",
     None),
    (344, 1,
     "名（＋助词）＋はもちろん（はもとより）～も",
     "……就不用说了；（就连）……也",
     None),
    (355, 1,
     "名＋にかけて（にかけては、にかけても、にかけての）",
     "在……方面；论……的话",
     None),
    (372, 1,
     "名/动-る＋につけ（につけて、につけては、につけても）",
     "每当……",
     "接在「見る、聞く、読む、思い出す」等动词后面，表示每逢此时、此景，都会引发联想或感慨等心理活动。"),
    (376, 1,
     "（1）名/ナ-だ/イ-い/动-る/活用词-た＋やら～やら",
     "……啦……啦",
     "用于并列、列举同类事项，强调数量众多，但语气略显消极。"),
    (393, 1,
     "动-る＋までもない（までのこともない）",
     "无需……；不至于……",
     None),
    (396, 1,
     "名/ナ-だ/イ-い/动-る/活用词-た＋にもかかわらず",
     "尽管……然而……",
     None),
    (401, 1,
     "名/ナ-だ/イ-い/动-る/活用词-た＋だろうに（でしょうに）",
     "本来……可是……",
     '表示转折，比「～のに」（N4）多了一份推测的语气，并带有\u201c遗憾、惋惜、意外、惊讶\u201d等心情。也有「～まいに」的用法，与「～ないだろうに」意思相同。'),
]

for gid, sort, conn_val, meaning, tip in patches:
    mid = get_mid(gid, sort)
    if not mid:
        print(f"  ⚠️ 未找到 grammar_id={gid} sort={sort}")
        continue
    if tip is not None:
        c.execute("UPDATE grammar_meanings SET connection=?, meaning=?, tip=? WHERE id=?",
                  (conn_val, meaning, tip, mid))
    else:
        c.execute("UPDATE grammar_meanings SET connection=?, meaning=? WHERE id=?",
                  (conn_val, meaning, mid))
    print(f"  \u2705 #{gid}: meaning='{meaning}'")

# #9: 「あるまいに」例句标记为 tip_example
mid_401 = get_mid(401, 1)
c.execute("UPDATE grammar_examples SET is_tip_example=1 WHERE meaning_id=? AND sentence LIKE '%あるまいに%'",
          (mid_401,))
print(f"  \u2705 #401: tip_example 标记 ({c.rowcount}条)")

# #10 ものだ: 义项1
mid_466_1 = get_mid(466, 1)
c.execute("UPDATE grammar_meanings SET connection=?, meaning=?, tip=? WHERE id=?",
          ("（1）ナ-な/イ-い/动-る/动-ない＋ものだ",
           "（其本质）原本就是……",
           "表示对带有真理性的、普遍性的事物，就其本来所具有的性质、特性等发表感想。主体不是个别事物，而是统称性、概括性的事物。",
           mid_466_1))
print(f"  \u2705 #466 义项1: meaning='（其本质）原本就是……'")

# 补充义项1缺失的例句
new_ex = [
    ("名と利はすぐ無くなるものだ。", "名和利，本来就是转眼即逝的东西。"),
    ("女のことは本当に分からないものだ。", "女人真让人琢磨不透。"),
]
for sent, trans in new_ex:
    c.execute("SELECT COUNT(*) FROM grammar_examples WHERE meaning_id=? AND sentence LIKE ?",
              (mid_466_1, f"%{sent[:15]}%"))
    if c.fetchone()[0] == 0:
        c.execute("SELECT COALESCE(MAX(sort_order),0)+1 FROM grammar_examples WHERE meaning_id=?",
                  (mid_466_1,))
        ns = c.fetchone()[0]
        c.execute("INSERT INTO grammar_examples (meaning_id,sort_order,sentence,translation,is_tip_example) VALUES(?,?,?,?,0)",
                  (mid_466_1, ns, sent, trans))
        print(f"  \u2705 #466 义项1: +例句 '{sent[:25]}...'")

# #10 义项2
mid_466_2 = get_mid(466, 2)
c.execute("UPDATE grammar_meanings SET meaning=?, tip=? WHERE id=?",
          ("实在是……啊",
           "用于说话人对特定事物的感叹、感慨、赞叹等，不用于叙述说话人意志性的行为。对愿望表达感叹时，第三人称不能作主语（例句3）。",
           mid_466_2))
print(f"  \u2705 #466 义项2: meaning='实在是……啊'")

conn.commit()
conn.close()
print("\n全部修正完成!")
