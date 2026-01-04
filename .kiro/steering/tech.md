---
inclusion: always
---

# 技术栈与工程规范（Tech · 冻结版）

> 本文档定义的是 **技术选型、工程规范与实现约束**
> 不裁决产品行为，不裁决数据与统计语义  
> 语义裁决以 `freeze.md` 为唯一依据

---

## 一、技术栈

### 核心框架

* **Flutter 3.38.1**
* **Dart SDK ^3.10.0**

定位：  
单代码库，多端一致行为（iOS / Android / Web / Desktop）

---

## 二、核心依赖说明

| 类别 | 包名 | 工程用途 |
|----|----|--------|
| 状态管理 | flutter_riverpod ^3.0.3 | Feature Controller / State 管理 |
| 数据库 | sqflite ^2.3.3 | 本地 SQLite |
| 路由 | go_router ^17.0.0 | 声明式路由 |
| 音频 | just_audio ^0.10.5 | 音频播放（由 AudioService 统一封装） |
| UI | ruby_text ^3.0.3 | 日文假名注音 |
| 动画 | flutter_animate ^4.5.0 | 声明式动画 |
| 手势 | gesture_x_detector ^1.1.1 | 高级手势识别 |
| 工具 | kana_kit ^2.1.1 | 假名 / 罗马音转换 |
| 网络 | dio ^5.7.0 | HTTP 客户端 |
| 日志 | logger ^2.5.0 | 统一日志封装 |
| 国际化 | intl ^0.20.2 | 多语言支持 |

> 依赖选择目标：**可维护性优先于“新”与“炫”**

---

## 三、架构模式（工程实现）

**MVVM + Command / Query / Analytics / Repository + Session + Riverpod**

```

View → Controller
├─→ Query        (Read-only)
├─→ Analytics   (Read-only Aggregation)
└─→ Command     (Write / Side Effects)
↓
Repository (Single-table CRUD)
↓
Database

```

> 本结构用于 **工程解耦与职责隔离**  
> 不用于裁决任何学习或统计语义

---

## 四、层级职责与工程约束

| 层级 | 工程职责 | 明确禁止 |
|----|--------|--------|
| **View** | UI 渲染、交互 | 统计计算、DB / Repository |
| **Controller** | 流程编排、状态调度 | Repository / DB |
| **Command** | 写行为入口、副作用触发 | 返回 Map / SQL |
| **Query** | 只读查询 | 写操作 |
| **Analytics** | 聚合统计（只读） | 写操作 |
| **Repository** | 单表 CRUD | join / 统计 / 业务判断 |
| **Model** | 数据结构 | 行为逻辑 |
| **State** | 不可变状态 | 可变字段 |
| **External** | 外部 API / SDK | 本地持久化 |

---

## 五、Command 与 Session 的工程关系

### 写入路径分类（工程视角）

| 写入类型 | 责任组件 | 是否经 Session |
|--------|---------|---------------|
| 状态写入 | WordCommand / KanaCommand | ❌ |
| 行为日志 | 对应 Command | ❌ |
| 统计写入 | Session / DailyStatCommand | ✅ / ❌ |

> 技术层 **只声明写路径**
> 写入语义由 `freeze.md` 冻结

---

### Session 的工程定位

Session 是**统计聚合工具**，而非通用写入口。

**只用于**：

* 会话内统计累积
* flush 到 `daily_stats`

固定链路：

```

SessionStatPolicy
→ SessionStatAccumulator
→ flush
→ DailyStatCommand

```

---

## 六、学习时长统计（工程特例）

* 数据来源：`PageDurationTracker`
* 写入口：`DailyStatCommand.applyTimeOnlyDelta`
* 不经过 Session
* 不写行为日志

这是 **工程层唯一允许绕过 Session 的统计写路径**。

---

## 七、命名规范

| 类型 | 规范 | 示例 |
|----|----|----|
| 文件名 | snake_case | `word_repository.dart` |
| 类名 | PascalCase | `WordRepository` |
| 方法 / 变量 | camelCase | `getWordById()` |
| 数据库列 | snake_case | `created_at` |
| 常量 | lowerCamelCase | `defaultEaseFactor` |

---

## 八、Feature 模块结构

```

lib/features/{feature}/
├── controller/
├── state/
├── pages/
└── widgets/ (可选)

````

---

## 九、数据层文件规范

* Model：`lib/data/models/{entity}.dart`
* Read DTO：`lib/data/models/read/{dto}.dart`
* Repository：`lib/data/repositories/{entity}_repository.dart`
* Query：`lib/data/queries/{entity}_query.dart`
* Analytics：`lib/data/analytics/{entity}_analytics.dart`
* Command：`lib/data/commands/{entity}_command.dart`
* External：`lib/data/external/{name}_client.dart`

---

## 十、国际化规范（强制）

所有用户可见文本 **必须使用 `AppLocalizations`**：

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.startLearning);
````

❌ 禁止硬编码字符串。

---

## 十一、日志规范

* 使用统一封装的 `logger`
* ❌ 禁止 `print()`

```dart
logger.i('Session started');
logger.w('Audio missing: $path');
logger.e('DB error', error: e, stackTrace: stackTrace);
```

---

## 十二、数据模型约定

* Model 必须实现 `fromMap()` / `toMap()`
* 所有时间字段使用 **秒级时间戳存储**

```dart
final seconds = map['created_at'] as int;
final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
```

---

## 十三、Riverpod 使用规范

| Provider           | 用途                                       |
| ------------------ | ---------------------------------------- |
| `NotifierProvider` | Feature Controller                       |
| `Provider`         | Command / Query / Analytics / Repository |

---

## 十四、UI / UX 工程规范

* 假名注音统一使用 `ruby_text`
* 音频统一通过 `AudioService`
* 遵循 `flutter_lints`
* 使用 `dart format`

---

## 十五、路由规范

```dart
context.go('/home');
context.pop();
context.replace('/login');
```

---

## 十六、数据库工程配置

* 数据库文件：`assets/database/breeze_jp.sqlite`
* 生命周期管理：`lib/data/db/`
* Repository 使用 Database Provider 注入
* Query / Analytics 使用 `databaseProvider`
* 当前用户由 `ActiveUserCommand / ActiveUserQuery` 管理

---

## 十七、技术文档冻结声明

> 本文档回答的问题是：
> **“在 BreezeJP 中，代码应该如何被正确地写”**

它不回答：

* 产品该怎么做
* 学习语义如何裁决
* 统计口径如何定义

若出现冲突：

**Freeze > Product > Structure > Tech**

---

### ⛔ Hard Stop

> **任何为了“图省事”而违反工程边界的实现，
> 都视为技术债，而不是工程效率。**

```

---