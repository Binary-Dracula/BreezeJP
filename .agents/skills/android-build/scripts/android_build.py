from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path


def project_root() -> Path:
    # scripts/android_build.py -> android_build -> skills -> .agents -> project root
    return Path(__file__).resolve().parents[4]


def read_version(pubspec_path: Path) -> str:
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s#]+)", content, re.MULTILINE)
    if not match:
        raise ValueError("pubspec.yaml 缺少 version 字段")
    raw_version = match.group(1).strip()
    # e.g. 0.1.1+3 -> 0.1.1
    return raw_version.split("+")[0]


def run_flutter_build(cwd: Path) -> None:
    cmd = ["flutter", "build", "appbundle"]
    result = subprocess.run(cmd, cwd=str(cwd), check=False)
    if result.returncode != 0:
        raise RuntimeError("flutter build appbundle 失败")


def build_android() -> int:
    root = project_root()
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        print(f"❌ 找不到文件: {pubspec}")
        return 1

    try:
        version = read_version(pubspec)
    except Exception as exc:  # noqa: BLE001
        print(f"❌ 读取版本号失败: {exc}")
        return 1

    print(f"检测到版本号: {version}")
    print("正在开始 Android App Bundle 打包...")

    try:
        run_flutter_build(root)
    except Exception as exc:  # noqa: BLE001
        print(f"❌ 打包失败: {exc}")
        return 1

    source_path = root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
    if not source_path.exists():
        print(f"❌ 找不到生成的 AAB 文件: {source_path}")
        return 1

    release_dir = root / "release"
    release_dir.mkdir(parents=True, exist_ok=True)
    target_path = release_dir / f"breeze_jp_v{version}_release.aab"
    shutil.copy2(source_path, target_path)

    print(f"✅ 打包成功！输出路径: {target_path}")
    return 0


if __name__ == "__main__":
    sys.exit(build_android())