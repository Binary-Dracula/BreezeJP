"""
速率限制器
=========
支持 RPM（每分钟请求数）、TPM（每分钟 Token 数）、RPD（每日请求数）三维度限流。
RPD 计数持久化到磁盘，跨进程、跨日累计。
"""

import json
import time
import threading
from datetime import datetime, date
from pathlib import Path


class RateLimiter:
    def __init__(self, rpm: int, tpm: int, rpd: int, checkpoint_file: Path = None):
        self.rpm = rpm
        self.tpm = tpm
        self.rpd = rpd
        self.checkpoint_file = checkpoint_file

        self._lock = threading.Lock()
        self._minute_requests: list[float] = []
        self._minute_tokens: list[tuple[float, int]] = []
        self._daily_count = 0
        self._daily_date = date.today().isoformat()

        self._load_checkpoint()

    # ------------------------------------------------------------------
    # 持久化
    # ------------------------------------------------------------------

    def _load_checkpoint(self):
        if not self.checkpoint_file or not self.checkpoint_file.exists():
            return
        try:
            with open(self.checkpoint_file, "r") as f:
                data = json.load(f)
            if data.get("date") == date.today().isoformat():
                self._daily_count = data.get("daily_count", 0)
                self._daily_date = data["date"]
            # 不同日期 → 自动重置
        except (json.JSONDecodeError, KeyError, IOError):
            pass

    def _save_checkpoint(self):
        if not self.checkpoint_file:
            return
        self.checkpoint_file.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.checkpoint_file.with_suffix(".tmp")
        with open(tmp, "w") as f:
            json.dump({
                "date": self._daily_date,
                "daily_count": self._daily_count,
                "updated_at": datetime.now().isoformat(),
            }, f)
        tmp.rename(self.checkpoint_file)

    # ------------------------------------------------------------------
    # 滑动窗口清理
    # ------------------------------------------------------------------

    def _clean_minute_window(self):
        cutoff = time.time() - 60
        self._minute_requests = [t for t in self._minute_requests if t > cutoff]
        self._minute_tokens = [(t, c) for t, c in self._minute_tokens if t > cutoff]

    # ------------------------------------------------------------------
    # 查询接口
    # ------------------------------------------------------------------

    @property
    def rpd_remaining(self) -> int:
        with self._lock:
            self._check_day_rollover()
            return max(0, self.rpd - self._daily_count)

    @property
    def rpm_current(self) -> int:
        with self._lock:
            self._clean_minute_window()
            return len(self._minute_requests)

    @property
    def tpm_current(self) -> int:
        with self._lock:
            self._clean_minute_window()
            return sum(c for _, c in self._minute_tokens)

    def _check_day_rollover(self):
        today = date.today().isoformat()
        if self._daily_date != today:
            self._daily_count = 0
            self._daily_date = today

    # ------------------------------------------------------------------
    # 控制接口
    # ------------------------------------------------------------------

    def check_rpd(self) -> bool:
        """检查每日配额是否还有余量。"""
        return self.rpd_remaining > 0

    def wait_if_needed(self, estimated_tokens: int = 0):
        """阻塞直到 RPM 和 TPM 允许下一次请求。"""
        while True:
            with self._lock:
                self._clean_minute_window()
                rpm_ok = len(self._minute_requests) < self.rpm
                tpm_ok = (sum(c for _, c in self._minute_tokens) + estimated_tokens) <= self.tpm
                if rpm_ok and tpm_ok:
                    return
            time.sleep(1.0)

    def record_request(self, token_count: int = 0):
        """记录一次已完成请求，更新所有维度计数器。"""
        with self._lock:
            now = time.time()
            self._minute_requests.append(now)
            if token_count > 0:
                self._minute_tokens.append((now, token_count))

            self._check_day_rollover()
            self._daily_count += 1
            self._save_checkpoint()

    # ------------------------------------------------------------------
    # 状态报告
    # ------------------------------------------------------------------

    def status(self) -> dict:
        with self._lock:
            self._clean_minute_window()
            return {
                "rpm_current": len(self._minute_requests),
                "rpm_limit": self.rpm,
                "tpm_current": sum(c for _, c in self._minute_tokens),
                "tpm_limit": self.tpm,
                "rpd_used": self._daily_count,
                "rpd_limit": self.rpd,
                "rpd_remaining": max(0, self.rpd - self._daily_count),
            }
