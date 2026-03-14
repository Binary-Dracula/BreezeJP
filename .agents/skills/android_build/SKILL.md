---
name: Android Build Skill
description: 自动化执行 Flutter Android 打包 (AAB)，并将打包产物统一输出到项目根根目录下的 release 文件夹，遵循规范化的命名约定。
---

# Android Build Skill

此 Skill 用于规范化应用的 Android 打包流程，确保生成的 `.aab` 文件具有一致的命名规则并存放在固定的 release 目录。

## 核心功能

1.  **自动读取版本号**：从 `pubspec.yaml` 中自动提取当前应用版本（例如 `0.1.1`）。
2.  **规范化命名**：生成的 AAB 文件将命名为 `breeze_jp_v{version}_release.aab`。
3.  **指定输出目录**：所有打包产物将集中存放在项目根目录的 `release/` 文件夹中。
4.  **构建清理集成**：在打包前会自动处理相关环境。

## 使用方法

直接调用此 Skill 或运行对应的打包脚本。

### 脚本路径
`python3 .agents/scripts/android_build/android_build.py`

## 文件结构规范

- **打包输出**：`release/breeze_jp_v{version}_release.aab`
- **构建缓存**：`build/app/outputs/bundle/release/app-release.aab`

## 验证步骤

1.  确认 `pubspec.yaml` 中的版本号。
2.  运行脚本：`python3 .agents/scripts/android_build/android_build.py`。
3.  检查根目录下是否生成了 `release` 目录及对应的 `.aab` 文件。
