---
name: android-build
description: "Build Flutter Android AAB and copy artifact to release/. Use when: android 打包, 生成 aab, 发布包构建, release 产物输出。"
argument-hint: "Run Android AAB build now"
---

# Android Build

规范化 Flutter Android AAB 打包流程，确保产物统一输出到项目根目录 `release/`，并使用固定命名规则。

## When to Use

- 需要生成 Android 发布包（`.aab`）
- 需要统一 release 产物命名与输出路径
- 用户提到「打包 Android」「构建 AAB」「发布构建」

## Skill Resources

- 构建脚本: [scripts/android_build.py](./scripts/android_build.py)

## Procedure

1. 在项目根目录确认 `pubspec.yaml` 存在，且 `version` 字段正确。
2. 运行脚本：
   `python3 .agents/skills/android-build/scripts/android_build.py`
3. 脚本会执行 `flutter build appbundle`。
4. 产物从 `build/app/outputs/bundle/release/app-release.aab` 复制到 `release/`。
5. 最终文件名为 `breeze_jp_v{version}_release.aab`（`version` 取自 `pubspec.yaml` 的主版本，不含 `+build`）。

## Output

- `release/breeze_jp_v{version}_release.aab`

## Validation

1. 检查终端返回码为 `0`。
2. 确认 `release/` 下生成目标 `.aab` 文件。
3. 文件名版本号与 `pubspec.yaml` 一致。
