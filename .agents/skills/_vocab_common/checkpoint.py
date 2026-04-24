"""
断点续传（Checkpoint）
====================
原子写入 JSON 文件，支持跨进程恢复。
"""

import json
from datetime import datetime
from pathlib import Path


class Checkpoint:
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self._data = self._load()

    def _load(self) -> dict:
        if self.filepath.exists():
            try:
                with open(self.filepath, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}

    def save(self):
        """原子写入：先写临时文件再 rename，避免中途崩溃导致损坏。"""
        self.filepath.parent.mkdir(parents=True, exist_ok=True)
        self._data["_updated_at"] = datetime.now().isoformat()
        tmp = self.filepath.with_suffix(".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self._data, f, ensure_ascii=False, indent=2)
        tmp.rename(self.filepath)

    def get(self, key, default=None):
        return self._data.get(key, default)

    def set(self, key, value):
        self._data[key] = value
        self.save()

    def get_set(self, key) -> set:
        """读取一个存储为 list 的 set。"""
        return set(self._data.get(key, []))

    def add_to_set(self, key, value):
        """向 set 添加值并持久化。"""
        s = self.get_set(key)
        s.add(value)
        self._data[key] = sorted(s)
        # 注意：不在此处 save()，由调用方决定 save 时机以避免频繁 IO

    def batch_save_set(self, key, values: set):
        """批量写入整个 set 并持久化。"""
        existing = self.get_set(key)
        existing.update(values)
        self._data[key] = sorted(existing)
        self.save()

    @property
    def data(self) -> dict:
        return self._data

    def clear(self):
        self._data = {}
        self.save()
