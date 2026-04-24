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


def run_flutter_build(cwd: Path, artifact: str) -> None:
    cmd = ["flutter", "build", artifact, "--release"]
    result = subprocess.run(cmd, cwd=str(cwd), check=False)
    if result.returncode != 0:
        raise RuntimeError(f"flutter build {artifact} 失败")


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
    print("正在开始 Android Release 打包（AAB + APK）...")

    try:
        print("\n[1/2] 构建 Android App Bundle...")
        run_flutter_build(root, "appbundle")
        print("\n[2/2] 构建 Android APK...")
        run_flutter_build(root, "apk")
    except Exception as exc:  # noqa: BLE001
        print(f"❌ 打包失败: {exc}")
        return 1

    aab_source_path = root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
    apk_source_path = root / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not aab_source_path.exists():
        print(f"❌ 找不到生成的 AAB 文件: {aab_source_path}")
        return 1
    if not apk_source_path.exists():
        print(f"❌ 找不到生成的 APK 文件: {apk_source_path}")
        return 1

    release_dir = root / "release"
    release_dir.mkdir(parents=True, exist_ok=True)
    aab_target_path = release_dir / f"breeze_jp_v{version}_release.aab"
    apk_target_path = release_dir / f"breeze_jp_v{version}_release.apk"
    shutil.copy2(aab_source_path, aab_target_path)
    shutil.copy2(apk_source_path, apk_target_path)

    print("✅ 打包成功！输出路径:")
    print(f"- {aab_target_path}")
    print(f"- {apk_target_path}")
    return 0


if __name__ == "__main__":
    sys.exit(build_android())