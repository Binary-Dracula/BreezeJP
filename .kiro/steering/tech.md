---
inclusion: always
---

# 技术栈与开发规范

## 框架与语言

- **Flutter 3.38.1** (Dart SDK ^3.10.0)
- 跨平台移动应用（iOS、Android、Web、Desktop）

## 核心依赖

| 类别 | 依赖 | 版本 | 用途 |
|------|------|------|------|
| 状态管理 | flutter_riverpod | ^3.0.3 | 响应式状态管理 |
| 数据库 | sqflite | ^2.3.3 | SQLite 本地数据库 |
| 路径 | path | ^1.9.0 | 路径操作 |
| 路径 | path_provider | ^2.1.3 | 系统文件路径 |
| 路由 | go_router | ^17.0.0 | 声明式路由管理 |
| 音频 | just_audio | ^0.10.5 | 单词/例句发音播放 |
| UI | ruby_text | ^3.0.3 | 假名注音渲染 |
| 动画 | flutter_animate | ^4.5.0 | 声明式动画 |
| 手势 | gesture_x_detector | ^1.1.1 | 高级手势识别 |
| 工具 | kana_kit | ^2.1.1 | 假名/罗马音转换 |
| 网络 | dio | ^5.7.0 | HTTP 请求 |
| 日志 | logger | ^2.5.0 | 日志输出 |
| 国际化 | intl | ^0.20.2 | 多语言支持 |
| JSON | json_annotation | ^4.9.0 | JSON 序列化注解 |

### 开发依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| flutter_lints | ^6.0.0 | 代码检查规则 |
| build_runner | ^2.4.8 | 代码生成工具 |
| json_serializable | ^6.8.0 | JSON 序列化生成器 |

## 架构模式

**MVVM + Repository + Riverpod**

```
View (UI) ←→ ViewModel (Controller/State) ←→ Repository ←→ Database
```

### 各层职责

- **View**：展示 UI，接收用户操作
- **ViewModel/Controller**：管理状态和业务逻辑
- **Repository**：封装数据库操作
- **Model**：数据结构

### 核心约束

- 数据库操作必须通过 Repository → ViewModel → View 链路
- View 不直接访问数据库或修改 Model
- Repository 返回 Model 对象，不返回 Map
- Repository 仅提供 CRUD 操作，不包含复杂的业务逻辑
- ViewModel 仅提供业务逻辑，不包含数据处理逻辑
- View 不包含业务逻辑，仅负责 UI 展示

## 代码规范

- 注意常量的定义和使用
- 不要在代码内硬编码,要使用国际化

### 命名约定

| 类型 | 风格 | 示例 |
|------|------|------|
| 文件名 | snake_case | `app_database.dart` |
| 类名 | PascalCase | `AppDatabase` |
| 变量/函数 | camelCase | `wordId`, `fromMap()` |
| 数据库列名 | snake_case | `word_id`, `jlpt_level` |

### 文件命名

- Controller: `{feature}_controller.dart`
- State: `{feature}_state.dart`
- Page: `{feature}_page.dart`
- Widget: `{feature}_{widget}.dart`
- Repository: `{model}_repository.dart`
- Model: 与表名一致，如 `word.dart`

### 数据模型

- 位于 `lib/data/models/`
- 必须实现 `fromMap()` 和 `toMap()`
- 数据库列名 (snake_case) 映射到 Dart 属性 (camelCase)

### 状态管理

- 使用 `NotifierProvider` 或 `StateNotifierProvider`
- UI 通过 `ConsumerWidget` 或 `ref.watch` 绑定
- 每个 feature 拥有独立 provider

### UI 开发

- 日文文本使用 `ruby_text` 显示 Furigana
- 例句高亮使用 `<b>` 标签，View 解析显示
- 音频播放通过 `AudioService`，与 Repository 分离

### 代码风格

- 遵循 `flutter_lints` 规则
- 使用 `dart format` 格式化
- 避免 `print()`，使用 `logger`
- 注释使用中文

## 常用命令

```bash
# 依赖管理
flutter pub get
flutter pub upgrade

# 运行
flutter run
flutter run -d chrome
flutter run -d macos

# 代码生成
flutter pub run build_runner build
flutter pub run build_runner build --delete-conflicting-outputs

# 代码质量
flutter analyze
flutter test
dart format lib/

# 构建
flutter build apk --release
flutter build ios --release
flutter build web --release

# 清理
flutter clean
```

## 数据库配置

- 预置数据库：`assets/database/breeze_jp.sqlite`
- 首次启动从 assets 复制到应用文档目录
- 单例访问：`AppDatabase.instance`

## 音频资源

## 本地化

- 主要内容：日语
- 翻译语言：中文（简体）
- 代码注释：中文
- UI 文本：目前仅支持中文
