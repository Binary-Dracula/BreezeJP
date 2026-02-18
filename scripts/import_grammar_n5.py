#!/usr/bin/env python3
"""
从 N5.xlsx 提取语法数据，导入到 SQLite 三表结构：
    grammars → grammar_meanings → grammar_examples

用法: python3 scripts/import_grammar_n5.py [--dry-run]
"""

import sys
import re
import sqlite3
import shutil
from pathlib import Path
from datetime import datetime

try:
    import openpyxl
except ImportError:
    print("需要安装 openpyxl: pip3 install openpyxl")
    sys.exit(1)

DB_PATH = "assets/database/breeze_jp.sqlite"
XLSX_PATH = "files/N5.xlsx"

# === 解析逻辑 ===

def read_all_lines(xlsx_path: str) -> list[str]:
    """
    读取 xlsx 所有单元格内容，展开多行单元格为独立行。
    返回扁平化后的文本行列表。
    """
    wb = openpyxl.load_workbook(xlsx_path)
    ws = wb["Sheet1"]
    
    lines = []
    for row in ws.iter_rows(values_only=False):
        # 取该行所有非空单元格值
        vals = [cell.value for cell in row if cell.value is not None]
        if not vals:
            continue
        
        # 取第一个单元格的文本（数据都在 A 列）
        cell_text = str(vals[0]).strip()
        if not cell_text:
            continue
        
        # 将多行单元格拆成独立行
        for sub_line in cell_text.split('\n'):
            sub_line = sub_line.strip()
            if sub_line:
                lines.append(sub_line)
    
    return lines


def normalize_spaced(text: str) -> str:
    """将 '接 续' / '意 思' 等间隔字恢复为正常形式"""
    text = re.sub(r'接\s+续', '接续', text)
    text = re.sub(r'意\s+思', '意思', text)
    text = re.sub(r'提\s+示', '提示', text)
    return text


def parse_lines(lines: list[str]) -> list[dict]:
    """
    对扁平化的行列表进行状态机解析。

    返回:
    [
        {
            "title": "~ています",
            "meanings": [
                {
                    "connection": "动-て+います",
                    "meaning": "正在……",
                    "tip": "表示...",
                    "examples": [{"sentence": "...", "translation": "..."}],
                    "tip_examples": [{"sentence": "...", "translation": "..."}],
                }
            ]
        }
    ]
    """
    # 模式定义
    grammar_title_re = re.compile(r'^(\d+)\s*[\.\．]\s*(.+)$')
    connection_re = re.compile(r'^接续\s*(.*)$')
    meaning_re = re.compile(r'^意思\s*(.*)$')
    numbered_re = re.compile(r'^(\d+)\s*[\.\．]\s*(.+)$')
    example_re = re.compile(r'[◎○]')
    lesson_re = re.compile(r'^第\d+课')
    tip_re = re.compile(r'^提示$')
    exercise_re = re.compile(r'练习|模拟试题|模拟考试')
    
    grammars = []
    current_grammar = None
    current_meaning = None
    in_tip = False
    
    # 找到内容开始（跳过前言/目录）
    start_idx = 0
    for i, line in enumerate(lines):
        norm = normalize_spaced(line)
        m = grammar_title_re.match(norm)
        if m and ('~' in m.group(2) or 'もう' in m.group(2) or 'まだ' in m.group(2)):
            start_idx = i
            break
        if lesson_re.match(norm):
            start_idx = i
            break
    
    for i in range(start_idx, len(lines)):
        raw = lines[i]
        line = normalize_spaced(raw)
        
        # 跳过课标题
        if lesson_re.match(line):
            continue
        
        # 停止于练习区域
        if exercise_re.search(line):
            break
        
        # 检测语法标题: "1.~ています"
        m = grammar_title_re.match(line)
        if m and ('~' in m.group(2) or 'もう' in m.group(2) or 'まだ' in m.group(2)):
            # 保存上一条
            if current_grammar:
                if current_meaning:
                    current_grammar["meanings"].append(current_meaning)
                    current_meaning = None
                grammars.append(current_grammar)
            
            current_grammar = {"title": m.group(2).strip(), "meanings": []}
            in_tip = False
            continue
        
        if not current_grammar:
            continue
        
        # 检测接续行: "接续 动-て+います"
        cm = connection_re.match(line)
        if cm:
            # 保存之前的义项
            if current_meaning:
                current_grammar["meanings"].append(current_meaning)
            
            conn_text = cm.group(1).strip()
            # 清理编号 "(1)" 
            conn_text = re.sub(r'^\(\s*\d+\s*\)\s*', '', conn_text).strip()
            
            current_meaning = {
                "connection": conn_text if conn_text else None,
                "meaning": None,
                "tip": None,
                "examples": [],
                "tip_examples": [],
            }
            in_tip = False
            continue
        
        # 检测意思行: "意思正在……" 或 "意思 (酌情翻译)"
        mm = meaning_re.match(line)
        if mm:
            meaning_text = mm.group(1).strip()
            if meaning_text:
                # 清理如 "(酌情翻译)" 
                if '酌情' in meaning_text:
                    meaning_text = meaning_text
                
                if current_meaning is None:
                    current_meaning = {
                        "connection": None,
                        "meaning": meaning_text,
                        "tip": None,
                        "examples": [],
                        "tip_examples": [],
                    }
                else:
                    current_meaning["meaning"] = meaning_text
            continue
        
        # 检测提示标记
        if tip_re.match(line):
            in_tip = True
            continue
        
        # 检测例句: 包含 ◎ 或 ○
        if example_re.search(line):
            parts = re.split(r'[◎○]', line)
            for part in parts:
                part = part.strip()
                if not part:
                    continue
                sentence, translation = _split_example(part)
                if sentence:
                    ex = {
                        "sentence": sentence,
                        "translation": translation,
                    }
                    if current_meaning:
                        if in_tip:
                            current_meaning["tip_examples"].append(ex)
                        else:
                            current_meaning["examples"].append(ex)
            continue
        
        # 检测编号意思行: "1. ……过去" "2. 表示..."
        nm = numbered_re.match(line)
        if nm and current_meaning is not None:
            number = int(nm.group(1))
            sub_meaning = nm.group(2).strip()
            
            if number > 1:
                # 多义项：新建一个义项，继承 connection
                current_grammar["meanings"].append(current_meaning)
                current_meaning = {
                    "connection": current_meaning.get("connection"),
                    "meaning": sub_meaning,
                    "tip": None,
                    "examples": [],
                    "tip_examples": [],
                }
            else:
                current_meaning["meaning"] = sub_meaning
            in_tip = False
            continue
        
        # 提示正文（非例句、非标题、非接续/意思）
        if in_tip and current_meaning:
            if current_meaning["tip"]:
                current_meaning["tip"] += line
            else:
                current_meaning["tip"] = line
            continue
        
        # 意思的补充行（没有接续/意思标记的普通行，且我们有 current_meaning 且还没有 meaning）
        if current_meaning and current_meaning["meaning"] is None and not in_tip:
            # 可能是意思内容的延续
            pass
    
    # 保存最后一条
    if current_grammar:
        if current_meaning:
            current_grammar["meanings"].append(current_meaning)
        grammars.append(current_grammar)
    
    return grammars


def _split_example(text: str) -> tuple[str, str | None]:
    """分离日语例句和中文翻译（以 / 分隔）"""
    text = re.sub(r'\s+', ' ', text).strip()
    
    parts = text.split('/')
    if len(parts) >= 2:
        for i in range(len(parts) - 1, 0, -1):
            if re.search(r'[\u4e00-\u9fff]', parts[i]):
                sentence = '/'.join(parts[:i]).strip()
                translation = '/'.join(parts[i:]).strip()
                return sentence, translation
    
    return text, None


# === 数据库操作 ===

def prepare_db(db_path: str):
    """备份并重建表结构"""
    backup_path = f"{db_path}.bak.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(db_path, backup_path)
    print(f"数据库备份: {backup_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 先删除旧表（有 FK 依赖顺序）
    cursor.execute("DROP TABLE IF EXISTS grammar_examples")
    cursor.execute("DROP TABLE IF EXISTS grammar_meanings")
    cursor.execute("DROP TABLE IF EXISTS study_grammars")
    cursor.execute("DROP TABLE IF EXISTS grammars")
    
    cursor.execute("""
        CREATE TABLE grammars (
            id           INTEGER PRIMARY KEY,
            title        TEXT NOT NULL,
            jlpt_level   TEXT,
            created_at   INTEGER,
            updated_at   INTEGER
        )
    """)
    
    cursor.execute("""
        CREATE TABLE grammar_meanings (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id   INTEGER NOT NULL REFERENCES grammars(id) ON DELETE CASCADE,
            sort_order   INTEGER NOT NULL DEFAULT 1,
            connection   TEXT,
            meaning      TEXT,
            tip          TEXT
        )
    """)
    cursor.execute("CREATE INDEX idx_grammar_meanings_grammar_id ON grammar_meanings (grammar_id)")
    
    cursor.execute("""
        CREATE TABLE grammar_examples (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            meaning_id      INTEGER NOT NULL REFERENCES grammar_meanings(id) ON DELETE CASCADE,
            sort_order      INTEGER NOT NULL DEFAULT 1,
            sentence        TEXT,
            translation     TEXT,
            is_tip_example  INTEGER DEFAULT 0,
            audio_url       TEXT
        )
    """)
    cursor.execute("CREATE INDEX idx_grammar_examples_meaning_id ON grammar_examples (meaning_id)")
    
    cursor.execute("""
        CREATE TABLE study_grammars (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id          INTEGER NOT NULL,
            grammar_id       INTEGER NOT NULL REFERENCES grammars(id),
            learning_status  INTEGER DEFAULT 0,
            next_review_at   INTEGER,
            last_reviewed_at INTEGER,
            streak           INTEGER DEFAULT 0,
            total_reviews    INTEGER DEFAULT 0,
            fail_count       INTEGER DEFAULT 0,
            interval         REAL DEFAULT 0,
            ease_factor      REAL DEFAULT 2.5,
            stability        REAL DEFAULT 0,
            difficulty       REAL DEFAULT 0,
            created_at       INTEGER,
            updated_at       INTEGER,
            UNIQUE(user_id, grammar_id)
        )
    """)
    
    conn.commit()
    print("新表结构已创建")
    return conn


def import_data(conn: sqlite3.Connection, grammars: list[dict], dry_run: bool = False):
    """将解析后的数据导入数据库"""
    cursor = conn.cursor()
    now = int(datetime.now().timestamp())
    
    g_count = m_count = e_count = 0
    
    for g_idx, grammar in enumerate(grammars, 1):
        if dry_run:
            print(f"\n[{g_idx}] {grammar['title']} ({len(grammar['meanings'])} 义项)")
            for m_idx, meaning in enumerate(grammar["meanings"], 1):
                conn_str = meaning.get("connection") or "(无)"
                mean_str = meaning.get("meaning") or "(无)"
                tip_str = f" [TIP]" if meaning.get("tip") else ""
                n_ex = len(meaning.get("examples", []))
                n_tip = len(meaning.get("tip_examples", []))
                print(f"  {m_idx}. [{conn_str}] → {mean_str}{tip_str} ({n_ex}+{n_tip}例句)")
                for ex in meaning.get("examples", []):
                    s = ex["sentence"][:60]
                    t = (ex.get("translation") or "")[:30]
                    print(f"    ◎ {s} / {t}")
                for ex in meaning.get("tip_examples", []):
                    s = ex["sentence"][:60]
                    print(f"    ◎ [TIP] {s}")
            continue
        
        cursor.execute(
            "INSERT INTO grammars (id, title, jlpt_level, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            (g_idx, grammar["title"], "N5", now, now)
        )
        g_count += 1
        
        for m_idx, meaning in enumerate(grammar["meanings"], 1):
            cursor.execute(
                "INSERT INTO grammar_meanings (grammar_id, sort_order, connection, meaning, tip) VALUES (?, ?, ?, ?, ?)",
                (g_idx, m_idx, meaning.get("connection"), meaning.get("meaning"), meaning.get("tip"))
            )
            mid = cursor.lastrowid
            m_count += 1
            
            sort = 1
            for ex in meaning.get("examples", []):
                cursor.execute(
                    "INSERT INTO grammar_examples (meaning_id, sort_order, sentence, translation, is_tip_example) VALUES (?, ?, ?, ?, 0)",
                    (mid, sort, ex["sentence"], ex.get("translation"))
                )
                sort += 1
                e_count += 1
            
            for ex in meaning.get("tip_examples", []):
                cursor.execute(
                    "INSERT INTO grammar_examples (meaning_id, sort_order, sentence, translation, is_tip_example) VALUES (?, ?, ?, ?, 1)",
                    (mid, sort, ex["sentence"], ex.get("translation"))
                )
                sort += 1
                e_count += 1
    
    if not dry_run:
        conn.commit()
    
    print(f"\n{'[DRY RUN] ' if dry_run else ''}导入完成: {g_count} 语法, {m_count} 义项, {e_count} 例句")


def main():
    dry_run = "--dry-run" in sys.argv
    
    if dry_run:
        print("=== DRY RUN 模式 ===\n")
    
    print(f"解析 {XLSX_PATH}...")
    all_lines = read_all_lines(XLSX_PATH)
    grammars = parse_lines(all_lines)
    print(f"共解析出 {len(grammars)} 条语法\n")
    
    if dry_run:
        import_data(sqlite3.connect(":memory:"), grammars, dry_run=True)
    else:
        conn = prepare_db(DB_PATH)
        import_data(conn, grammars)
        conn.close()
        print("完成!")


if __name__ == "__main__":
    main()
