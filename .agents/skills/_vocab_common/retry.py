"""
统一重试机制
===========
支持指数退避、可配置重试次数与延迟、特定异常识别。
"""

import time
import functools


def retry(
    max_retries: int = 5,
    base_delay: float = 2.0,
    max_delay: float = 60.0,
    retryable_exceptions: tuple = (Exception,),
    on_retry=None,
):
    """装饰器：为函数添加指数退避重试。"""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exc = None
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except retryable_exceptions as e:
                    last_exc = e
                    if attempt < max_retries:
                        delay = min(base_delay * (2 ** attempt), max_delay)
                        if on_retry:
                            on_retry(attempt + 1, max_retries, e, delay)
                        else:
                            print(f"  ⚠️ 重试 ({attempt + 1}/{max_retries}): {e}，等待 {delay:.1f}s...")
                        time.sleep(delay)
            raise last_exc
        return wrapper
    return decorator


def retry_call(
    func,
    args=(),
    kwargs=None,
    max_retries: int = 5,
    base_delay: float = 2.0,
    max_delay: float = 60.0,
    retryable_exceptions: tuple = (Exception,),
    on_retry=None,
):
    """函数式重试（非装饰器版本）。"""
    kwargs = kwargs or {}
    last_exc = None
    for attempt in range(max_retries + 1):
        try:
            return func(*args, **kwargs)
        except retryable_exceptions as e:
            last_exc = e
            if attempt < max_retries:
                delay = min(base_delay * (2 ** attempt), max_delay)
                if on_retry:
                    on_retry(attempt + 1, max_retries, e, delay)
                else:
                    print(f"  ⚠️ 重试 ({attempt + 1}/{max_retries}): {e}，等待 {delay:.1f}s...")
                time.sleep(delay)
    raise last_exc
