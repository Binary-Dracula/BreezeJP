"""
统一配置加载器
=============
从项目根目录 .env 文件加载配置，环境变量优先于 .env。
"""

import os
from pathlib import Path


def _find_project_root() -> Path:
    current = Path(__file__).resolve().parent
    for _ in range(10):
        if (current / "pubspec.yaml").exists():
            return current
        current = current.parent
    raise FileNotFoundError("找不到项目根目录（未发现 pubspec.yaml）")


PROJECT_ROOT = _find_project_root()


def _load_env() -> dict:
    env_path = PROJECT_ROOT / ".env"
    env_vars = {}
    if env_path.exists():
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if key and value:
                        env_vars[key] = value
    return env_vars


_ENV = _load_env()


def get(key: str, default=None, required=False) -> str:
    """获取配置值。环境变量 > .env 文件 > default。"""
    value = os.environ.get(key) or _ENV.get(key) or default
    if required and not value:
        raise ValueError(f"❌ 缺少必需配置: {key}\n   请在项目根目录 .env 文件或环境变量中设置。")
    return value


def gemini_api_key() -> str:
    return get("GEMINI_API_KEY", required=True)


def supabase_service_key() -> str:
    return get("SUPABASE_SERVICE_KEY", required=True)


def cloudflare_api_token() -> str:
    return get("CLOUDFLARE_API_TOKEN")


def moji_username() -> str:
    return get("MOJI_USERNAME", required=True)


def moji_password() -> str:
    return get("MOJI_PASSWORD", required=True)
