#!/usr/bin/env python3
"""NHK Easy News skill wrapper."""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def find_project_root() -> Path:
    current = Path(__file__).resolve().parent
    for _ in range(10):
        if (current / "pubspec.yaml").exists():
            return current
        current = current.parent
    raise FileNotFoundError("找不到项目根目录（未发现 pubspec.yaml）")


PROJECT_ROOT = find_project_root()
PIPELINE_DIR = PROJECT_ROOT / ".agents" / "skills" / "nhk-easy-news" / "pipeline"
PIPELINE_VENV = PIPELINE_DIR / "venv"
PIPELINE_SCRIPT = PIPELINE_DIR / "scripts" / "run_pipeline.sh"
UPLOAD_SCRIPT = PIPELINE_DIR / "scripts" / "upload_to_backend.py"
ENV_FILE = PROJECT_ROOT / ".env"


def load_env_file() -> dict:
    env_vars = {}
    if not ENV_FILE.exists():
        return env_vars
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env_vars[key.strip()] = value.strip().strip('"').strip("'")
    return env_vars


def ask_if_missing(value: str, prompt_text: str, allow_empty: bool = False) -> str:
    if value is not None:
        return value
    while True:
        result = input(prompt_text).strip()
        if result or allow_empty:
            return result


def main() -> int:
    parser = argparse.ArgumentParser(description="运行 NHK Easy News 数据管道")
    parser.add_argument("--hdnts", help="NHK 音频下载 token")
    parser.add_argument("--tokenizer", choices=["kuromoji", "sudachi"], help="分词器")
    parser.add_argument("--sudachi-mode", choices=["A", "B", "C"], help="Sudachi 模式")
    parser.add_argument("--upload", action="store_true", help="管道完成后上传到 Supabase + R2")
    args = parser.parse_args()

    if not PIPELINE_SCRIPT.exists():
        print(f"❌ 找不到 NHK 管道脚本: {PIPELINE_SCRIPT}")
        return 1

    if not PIPELINE_VENV.exists():
        print(f"❌ 找不到虚拟环境: {PIPELINE_VENV}")
        print("   请先在 .agents/skills/nhk-easy-news/pipeline/ 下创建 venv 并安装 requirements.txt")
        return 1

    hdnts = ask_if_missing(args.hdnts, "请输入 hdnts token（留空则跳过音频下载）: ", allow_empty=True)
    tokenizer = args.tokenizer or ask_if_missing(None, "选择分词器 [sudachi/kuromoji]，默认 sudachi: ", allow_empty=True) or "sudachi"
    sudachi_mode = args.sudachi_mode or "B"
    if tokenizer == "sudachi" and args.sudachi_mode is None:
        sudachi_mode = ask_if_missing(None, "选择 Sudachi 模式 [A/B/C]，默认 B: ", allow_empty=True) or "B"

    command = ["bash", str(PIPELINE_SCRIPT), "--tokenizer", tokenizer]
    if tokenizer == "sudachi":
        command.extend(["--sudachi-mode", sudachi_mode])
    if hdnts:
        command.extend(["--hdnts", hdnts])

    print("\n🚀 运行 NHK Easy News 管道...\n")
    result = subprocess.run(command, cwd=PIPELINE_DIR)
    if result.returncode != 0:
        return result.returncode

    if not args.upload:
        return 0

    env = os.environ.copy()
    env.update(load_env_file())

    if not env.get("SUPABASE_SERVICE_KEY"):
        print("\n❌ 未检测到 SUPABASE_SERVICE_KEY，跳过上传。")
        print("   如需上传，请先在项目根 .env 中设置。")
        return 1

    print("\n☁️ 上传 NHK 数据到后端...\n")
    upload_result = subprocess.run([sys.executable, str(UPLOAD_SCRIPT)], cwd=PIPELINE_DIR, env=env)
    return upload_result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
