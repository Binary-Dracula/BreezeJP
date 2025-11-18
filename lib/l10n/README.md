# 国际化 (i18n) 配置

## 概述

本项目使用 Flutter 官方的国际化方案，支持以下语言：
- 🇨🇳 中文 (zh) - 默认语言
- 🇯🇵 日语 (ja)
- 🇺🇸 英语 (en)

## 文件结构

```
lib/l10n/
├── app_zh.arb              # 中文翻译（模板文件）
├── app_ja.arb              # 日语翻译
├── app_en.arb              # 英语翻译
├── app_localizations.dart  # 自动生成的本地化类
├── app_localizations_zh.dart
├── app_localizations_ja.dart
└── app_localizations_en.dart
```

## 使用方法

### 1. 在 Widget 中使用

```dart
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Text(l10n.appName); // 显示 "Breeze JP"
  }
}
```

### 2. 带参数的翻译

```dart
// 在 .arb 文件中定义
{
  "splashInitFailed": "初始化失败: {error}",
  "@splashInitFailed": {
    "placeholders": {
      "error": {
        "type": "String"
      }
    }
  }
}

// 在代码中使用
Text(l10n.splashInitFailed('数据库错误'))
```

### 3. 在控制器中使用

由于控制器没有 BuildContext，需要从 UI 层传递：

```dart
// 控制器方法
Future<void> initialize(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  state = state.copyWith(message: l10n.splashInitializing);
}

// UI 层调用
ref.read(splashControllerProvider.notifier).initialize(context);
```

## 添加新的翻译

### 步骤 1: 在 ARB 文件中添加键值

在 `app_zh.arb` (模板文件) 中添加：

```json
{
  "newKey": "新的翻译文本",
  "@newKey": {
    "description": "这个键的说明"
  }
}
```

### 步骤 2: 在其他语言文件中添加对应翻译

在 `app_ja.arb` 和 `app_en.arb` 中添加相同的键：

```json
// app_ja.arb
{
  "newKey": "新しい翻訳テキスト"
}

// app_en.arb
{
  "newKey": "New translation text"
}
```

### 步骤 3: 重新生成代码

保存文件后，Flutter 会自动重新生成国际化代码。如果没有自动生成，运行：

```bash
flutter pub get
```

### 步骤 4: 在代码中使用

```dart
Text(l10n.newKey)
```

## 配置文件

### l10n.yaml

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
```

### pubspec.yaml

```yaml
flutter:
  generate: true

dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
```

## 当前已定义的翻译键

| 键名 | 中文 | 日语 | 英语 | 用途 |
|------|------|------|------|------|
| appName | Breeze JP | Breeze JP | Breeze JP | 应用名称 |
| appSubtitle | 日语学习助手 | 日本語学習アシスタント | Japanese Learning Assistant | 应用副标题 |
| splashInitializing | 正在初始化... | 初期化中... | Initializing... | Splash 初始化 |
| splashLoadingDatabase | 正在加载数据库... | データベースを読み込んでいます... | Loading database... | 数据库加载 |
| splashInitComplete | 初始化完成 | 初期化完了 | Initialization complete | 初始化完成 |
| splashInitFailed | 初始化失败: {error} | 初期化失敗: {error} | Initialization failed: {error} | 初始化失败 |
| retry | 重试 | 再試行 | Retry | 重试按钮 |
| homeWelcome | 欢迎使用 Breeze JP | Breeze JP へようこそ | Welcome to Breeze JP | 主页欢迎 |
| homeSubtitle | 开始你的日语学习之旅 | 日本語学習の旅を始めましょう | Start your Japanese learning journey | 主页副标题 |
| startLearning | 开始学习 | 学習を始める | Start Learning | 开始学习按钮 |
| databaseEmpty | 数据库为空，请检查数据文件 | データベースが空です。データファイルを確認してください | Database is empty, please check data files | 数据库为空错误 |
| databaseInitFailed | 数据库初始化失败: {error} | データベース初期化失敗: {error} | Database initialization failed: {error} | 数据库初始化失败 |

## 注意事项

1. **模板文件**: `app_zh.arb` 是模板文件，所有新键必须先在这里定义
2. **自动生成**: 修改 .arb 文件后，保存即可自动生成 Dart 代码
3. **类型安全**: 生成的代码是类型安全的，IDE 会提供自动补全
4. **参数化**: 支持占位符参数，如 `{error}`, `{count}` 等
5. **描述信息**: `@keyName` 用于添加描述和元数据，不会影响运行时

## 切换语言

应用会自动使用系统语言。如需手动切换，可以在 `MaterialApp.router` 中设置：

```dart
MaterialApp.router(
  locale: const Locale('ja'), // 强制使用日语
  // ...
)
```
