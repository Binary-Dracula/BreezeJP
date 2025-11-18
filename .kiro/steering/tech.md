---
inclusion: always
---

# 技术栈与开发规范

## 框架与语言

- **Flutter 3.38.1** (Dart SDK ^3.10.0)
- 跨平台移动应用（支持 iOS、Android、Web、Desktop）

## 核心依赖

### 状态管理
- `flutter_riverpod` ^3.0.3 - 响应式状态管理方案
  - 使用 Provider 模式管理应用状态
  - 支持依赖注入和状态隔离
  - 推荐使用 `ConsumerWidget` 或 `ConsumerStatefulWidget`

### 数据库
- `sqflite` ^2.3.3 - SQLite 本地数据库
- `path` ^1.9.0 - 路径操作工具
- `path_provider` ^2.1.3 - 获取系统文件路径
- 预置数据库：`assets/database/breeze_jp.sqlite`
- 首次启动时从 assets 复制到应用文档目录
- 使用单例模式访问：`AppDatabase.instance`

### 路由导航
- `go_router` ^17.0.0 - 声明式路由管理
  - 支持深链接和 URL 导航
  - 类型安全的路由定义
  - 路由配置位于 `lib/router/`

### 音频播放
- `just_audio` ^0.10.5 - 高性能音频播放器
  - 用于单词和例句发音播放
  - 支持多种音频格式（主要使用 MP3）
  - 音频文件位置：
    - 单词音频：`assets/audio/words/`
    - 例句音频：`assets/audio/examples/`

### UI 组件
- `ruby_text` ^3.0.3 - 假名注音（振り仮名）文本渲染
- `flutter_animate` ^4.5.0 - 声明式动画库
- `gesture_x_detector` ^1.1.1 - 高级手势识别

### 工具库
- `kana_kit` ^2.1.1 - 日语假名/罗马音转换
- `json_annotation` ^4.9.0 - JSON 序列化注解

### 开发依赖
- `flutter_lints` ^6.0.0 - Flutter 官方代码检查规则
- `build_runner` ^2.4.8 - 代码生成工具
- `json_serializable` ^6.8.0 - JSON 序列化代码生成器

## 架构模式

BreezeJP 采用 **MVVM + Repository + Riverpod** 架构：

```
View (UI) ←→ ViewModel (State/Controller) ←→ Repository ←→ Database
```

### 各层职责

- **View**：负责展示 UI 和接收用户操作（Pages / Widgets）
- **ViewModel / Controller**：管理状态、业务逻辑，提供给 View 可观察的数据
- **Repository**：封装数据库操作，处理数据获取和存储
- **Model**：数据结构（Word / WordMeaning / ExampleSentence / WordAudio / ExampleAudio）

### 核心约束

- 所有数据库操作不直接在 UI 中进行，必须通过 Repository → ViewModel → View 的链路
- View 不直接访问数据库或修改 Model
- 所有数据变更通过 Controller/ViewModel 触发
- Repository 返回 Model 对象或 List<Model>，而不是 Map

## 代码规范

### 命名约定

- **文件名**：`snake_case`（例：`app_database.dart`、`word_detail.dart`）
- **类名**：`PascalCase`（例：`AppDatabase`、`WordDetail`）
- **变量/函数**：`camelCase`（例：`wordId`、`fromMap()`）
- **数据库列名**：`snake_case`（例：`word_id`、`jlpt_level`）

### 文件命名规范

- Controller / ViewModel: `{feature}_controller.dart`、`{feature}_state.dart`
- Page: `{feature}_page.dart`
- Widget: `{feature}_{widget}.dart`
- Repository: `{model}_repository.dart`
- Model: 与表名一致，如 `word.dart`、`word_meaning.dart`

### 数据模型规范

- 位于 `lib/data/models/`
- 必须实现 `fromMap()` 工厂构造函数（从数据库反序列化）
- 必须实现 `toMap()` 方法（序列化到数据库）
- 数据库列名（snake_case）映射到 Dart 属性（camelCase）

### 状态管理规范

- 使用 **Flutter Riverpod** 进行状态管理
- 每个 feature 拥有独立 provider
- 使用 `StateNotifierProvider` 或 `NotifierProvider` 管理状态
- UI 通过 `ConsumerWidget` 或 `ref.watch` 绑定
- 控制器放在 `features/[功能名]/controller/`
- 状态类放在 `features/[功能名]/state/`
- Provider 定义在对应的控制器或状态文件中

### 数据库操作规范

- 所有 SQL 查询和 CRUD 操作必须封装在 Repository 内
- Repository 返回 Model 对象或 List<Model>，而不是 Map
- ViewModel 调用 Repository，处理业务逻辑后更新状态

### UI 开发规范

- View 不直接访问数据库
- 显示日文文本时使用 `ruby_text` 或自定义 Widget 显示 Furigana
- 例句高亮学习单词使用 `<b>` 标签，View 解析并显示
- 音频播放通过 `just_audio` 或自定义 `AudioService`，与 Repository / Model 分离

### 代码风格

- 遵循 `flutter_lints` 规则
- 使用 `dart format` 自动格式化
- 避免在生产代码中使用 `print()`，使用日志框架替代
- 所有注释使用中文
- 复杂逻辑必须添加注释说明

## 常用命令

### 依赖管理
```bash
# 获取依赖
flutter pub get

# 更新依赖
flutter pub upgrade

# 查看过期依赖
flutter pub outdated
```

### 开发与调试
```bash
# 运行应用（调试模式）
flutter run

# 运行并指定设备
flutter run -d chrome          # Web 浏览器
flutter run -d macos           # macOS 桌面

# 热重载（开发时按 r）
# 热重启（开发时按 R）
```

### 代码生成
```bash
# 一次性代码生成（JSON 序列化等）
flutter pub run build_runner build

# 监听模式，自动生成
flutter pub run build_runner watch

# 删除冲突文件后重新生成
flutter pub run build_runner build --delete-conflicting-outputs
```

### 构建发布
```bash
# Android APK
flutter build apk --release

# Android App Bundle（推荐用于 Google Play）
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# macOS
flutter build macos --release
```

### 代码质量
```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 测试覆盖率
flutter test --coverage

# 格式化代码
dart format lib/
```

### 清理与维护
```bash
# 清理构建产物
flutter clean

# 清理后重新获取依赖
flutter clean && flutter pub get
```

## 语言与本地化

- **主要内容**：日语（日本語）
- **翻译语言**：中文（简体中文）
- **代码注释**：中文
- **UI 文本**：支持中日双语（未来可扩展）

## 性能优化建议

- 使用 `const` 构造函数减少重建
- 列表使用 `ListView.builder` 实现懒加载
- 图片和音频资源按需加载
- 数据库查询结果适当缓存
- 避免在 `build()` 中创建新对象
- 异步操作使用 `async/await`
- 避免在 `build()` 方法中执行异步操作
- 使用 `FutureProvider` 或 `StreamProvider` 处理异步数据
- 音频播放器使用后及时 `dispose()`
- 数据库连接使用单例模式，避免重复打开

## 典型数据流示例（背单词页面）

```
View (LearnPage)
  ↓ ref.watch(learnControllerProvider)
ViewModel (LearnController / LearnState)
  ↓ 调用
Repository (WordRepository)
  ↓ 查询
Database (SQLite breeze_jp.sqlite)
```

UI 只负责显示和接收操作，所有业务逻辑都在 ViewModel 里，数据库操作完全在 Repository。
