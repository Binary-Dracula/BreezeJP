---
inclusion: always
---

# 技术栈与开发规范（冻结对齐版）

## 技术栈

**Flutter 3.38.1**（Dart SDK ^3.10.0）
跨平台移动应用（iOS / Android / Web / Desktop）

---

## 核心依赖

| 类别   | 包名                        | 用途                            |
| ---- | ------------------------- | ----------------------------- |
| 状态管理 | flutter_riverpod ^3.0.3   | MVVM 状态管理（`NotifierProvider`） |
| 数据库  | sqflite ^2.3.3            | SQLite 本地数据库                  |
| 路由   | go_router ^17.0.0         | 声明式路由                         |
| 音频   | just_audio ^0.10.5        | 音频播放（由 AudioService 封装）       |
| UI   | ruby_text ^3.0.3          | 日文假名注音                        |
| 动画   | flutter_animate ^4.5.0    | 声明式动画                         |
| 手势   | gesture_x_detector ^1.1.1 | 高级手势识别                        |
| 工具   | kana_kit ^2.1.1           | 假名/罗马音转换                      |
| 网络   | dio ^5.7.0                | HTTP 客户端                      |
| 日志   | logger ^2.5.0             | 日志输出（统一封装）                    |
| 国际化  | intl ^0.20.2              | 多语言支持                         |

---

## 架构模式（冻结）

**MVVM + Command / Query / Analytics / Repository + Session + Riverpod**

```
View → Controller
           ├─→ Query (Read)
           ├─→ Analytics (Read-only Statistics)
           └─→ Command (Behavior / Write)
                       ↓
                 Repository (Entity CRUD)
                       ↓
                    Database
```

---

## 层级职责与约束（冻结）

| 层级                    | 职责                         | 明确禁止                    |
| --------------------- | -------------------------- | ----------------------- |
| **View**              | UI 渲染、用户交互                 | 统计计算、直接 DB / Repository |
| **Controller**        | 流程编排、状态管理                  | 直接 DB / Repository      |
| **Command**           | 写行为、状态变更、副作用               | 返回 Map / SQL 原始结果       |
| **Command / Session** | 会话级统计聚合                    | 绕过规则写统计                 |
| **Query**             | 只读查询（join / list / detail） | 写操作                     |
| **Analytics**         | 聚合统计（只读）                   | 写操作                     |
| **Repository**        | 单表 CRUD                    | join / 统计 / 业务语义        |
| **External**          | 外部 API Client              | 本地持久化                   |
| **Model**             | 数据结构                       | 业务逻辑                    |
| **State**             | 不可变状态容器                    | 可变字段                    |

---

## 关键架构规则（强约束）

### 1️⃣ Controller 规则

* Controller **仅调用**：

  * Command
  * Query
  * Analytics
* ❌ 禁止：

  * 直接访问 Repository
  * 直接读写 `daily_stats / study_logs / kana_logs`

---

### 2️⃣ Repository 规则

* 仅包含 **单表 CRUD**
* 返回 **Model**
* ❌ 禁止：

  * join / count / group by
  * firstLearn / mastered 等业务语义

---

### 3️⃣ Query / Analytics 规则

* **只读**
* Query / Analytics 使用 `databaseProvider` 注入 Database
* ❌ 禁止：

  * 写操作
  * 使用 `AppDatabase.instance`

---

## Command 与 Session 的关系（重要冻结说明）

### 写入类型三分法（冻结）

| 写入类型     | 写入对象                                  | 责任组件                          | 是否经 Session |
| -------- | ------------------------------------- | ----------------------------- | ----------- |
| **状态写入** | `study_words` / `kana_learning_state` | `WordCommand` / `KanaCommand` | ❌           |
| **行为日志** | `study_logs` / `kana_logs`            | 对应 Command                    | ❌           |
| **统计写入** | `daily_stats`                         | Session / DailyStatCommand    | ✅ / ❌       |

> ⚠️ **关键澄清**
> “Session 是统计唯一入口”**不等于**“所有统计都走 Session”。

---

### Session 的唯一职责（冻结）

Session **只负责**：

* 今日学习数（new_learned_count）
* 今日复习数（review_count）
* 会话级统计聚合

Session 统计链路固定为：

```
SessionStatPolicy
   → SessionStatAccumulator
      → flush
         → DailyStatCommand.applySession
```

---

### Session 的明确不适用范围（冻结）

以下行为 **不经 Session，且是合法的**：

* Word / Kana 的 `seen` / `learning` / `mastered` / `ignored` 状态写入
* `firstLearn` 行为日志写入
* 学习时长统计（PageDurationTracker）

---

## 学习时长统计（冻结特例）

* **唯一来源**：`PageDurationTracker`
* **唯一写入口**：`DailyStatCommand.applyTimeOnlyDelta`
* ❌ 不经 Session
* ❌ 不写入 `study_logs`
* ❌ 不从 logs / 行为参数推导

这是 **唯一允许绕过 Session 的统计写入路径**。

---

## 命名规范

### 文件 / 标识符

| 类型    | 规范             | 示例                     |
| ----- | -------------- | ---------------------- |
| 文件名   | snake_case     | `word_repository.dart` |
| 类名    | PascalCase     | `WordRepository`       |
| 变量/方法 | camelCase      | `getWordById()`        |
| 数据库列  | snake_case     | `created_at`           |
| 常量    | lowerCamelCase | `defaultEaseFactor`    |

---

## Feature 模块结构（冻结）

```
lib/features/{feature}/
├── controller/
├── state/
├── pages/
└── widgets/ (可选)
```

---

## 数据层文件规范

* Model：`lib/data/models/{entity}.dart`
* Read DTO：`lib/data/models/read/{dto}.dart`
* Repository：`lib/data/repositories/{entity}_repository.dart`
* Query：`lib/data/queries/{entity}_query.dart`
* Analytics：`lib/data/analytics/{entity}_analytics.dart`
* Command：`lib/data/commands/{entity}_command.dart`
* External：`lib/data/external/{name}_client.dart`

---

## 国际化（强制）

**所有用户可见文本必须使用 `AppLocalizations`**

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.startLearning);
```

❌ 禁止硬编码字符串。

---

## 日志规范

* 使用统一封装的 `logger`
* ❌ 禁止 `print()`

```dart
logger.i('Session started');
logger.w('Audio missing: $path');
logger.e('DB error', error: e, stackTrace: stackTrace);
```

---

## 数据模型规范

* 所有 Model 必须实现 `fromMap()` / `toMap()`
* 时间统一使用 **秒级时间戳存储**

```dart
final seconds = map['created_at'] as int;
final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
```

---

## Riverpod 使用规范

### Provider 类型

| Provider           | 用途                                       |
| ------------------ | ---------------------------------------- |
| `NotifierProvider` | Feature Controller                       |
| `Provider`         | Command / Query / Analytics / Repository |

---

## UI / UX 开发规范

* 假名注音使用 `ruby_text`
* 音频通过 `AudioService`，不进 Repository
* 遵循 `flutter_lints`
* 使用 `dart format`

---

## 路由规范

```dart
context.go('/home');
context.pop();
context.replace('/login');
```

---

## 数据库配置

* 数据库路径：`assets/database/breeze_jp.sqlite`
* Database 生命周期由 `lib/data/db/` 管理
* Repository 使用 `AppDatabase.instance`
* Query / Analytics 使用 `databaseProvider`
* 当前用户由 `ActiveUserCommand / ActiveUserQuery` 管理

---

## 关键约束总结（Hard Stop）

1. ❌ Controller 直连 Repository / DB
2. ❌ Query / Analytics 写数据
3. ❌ 从 logs 推导统计
4. ❌ 在 UI / Controller 中计算统计
5. ❌ 为“展示好看”篡改统计口径
6. ✅ **所有写操作必须落在 Command（或 PageDurationTracker → DailyStatCommand）**

---

### 🔒 最终冻结声明

> **本文件与 Architecture Freeze、Learning Analytics Rules 同级。**
>
> 当实现与文档冲突时，
> **实现必错，文档必对。**
