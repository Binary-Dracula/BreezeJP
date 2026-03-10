---
inclusion: fileMatch
fileMatchPattern: ['lib/router/**/*.dart', 'lib/features/**/pages/*.dart', 'lib/debug/pages/**/*.dart']
---

# 路由系统实现指南（冻结版）

> **Status: FROZEN**
>
> 本文档定义 BreezeJP 中**唯一合法的路由系统实现方式**。
>
> 任何不符合本规则的路由改动，均视为 **架构违规**，不得合并。

---

## 一、概述

BreezeJP 使用 `go_router ^17.0.0` 实现 **声明式、集中式** 路由管理。

路由系统的职责**仅限于页面切换与参数传递**，**不承载任何业务逻辑、统计逻辑或状态推导**。

---

## 二、架构定位（强约束）

### Router 的职责边界

| 能做           | 不能做                   |
| -------------- | ------------------------ |
| 页面跳转       | ❌ 业务判断               |
| 参数传递       | ❌ 学习状态判断           |
| 导航栈管理     | ❌ 统计 / analytics       |
| Debug 页面入口 | ❌ Session / Command 调用 |

**Router ≠ Controller ≠ Feature 逻辑的一部分**

---

## 三、路由配置原则（冻结）

### 1️⃣ 单一数据源（Single Source of Truth）

* ✅ **所有路由**必须集中定义在：

```
lib/router/app_router.dart
```

* ❌ 禁止：

  * Feature 内部私自注册路由
  * 分散的子 Router
  * 动态拼装 Route 表

---

### 2️⃣ 初始路由固定

```text
/splash
```

* Splash 页面负责：

  * App 初始化
  * ActiveUser ensure
  * Database ready
* ❌ Router 不做任何初始化判断

---

### 3️⃣ 导航方式（冻结）

| 场景       | 方法                |
| ---------- | ------------------- |
| 普通跳转   | `context.go()`      |
| 替换当前栈 | `context.replace()` |
| 返回       | `context.pop()`     |

❌ 禁止：

* Navigator.push / pop
* imperative Navigator API
* 自定义 RouterDelegate

---

## 四、路径与参数规范（冻结）

### 路径风格

* **kebab-case**
* 层级清晰、可读

```text
/home
/learn/:wordId
/kana-chart
/debug/statistics
```

---

### 参数传递规则

* 仅使用 **路径参数**
* ❌ 核心导航不使用 query 参数

```dart
final wordIdStr = state.pathParameters['wordId'];
```

### 参数校验责任

* **页面构造函数负责校验**
* Router 不做业务兜底

```dart
if (wordIdStr == null) {
  return const ErrorPage();
}
```

---

## 五、当前路由结构（与代码一致）

| 路由                  | 页面                   | 模块                       | 参数     |
| --------------------- | ---------------------- | -------------------------- | -------- |
| `/splash`             | `SplashPage`           | `features/splash`          | 无       |
| `/home`               | `HomePage`             | `features/home`            | 无       |
| `/initial-choice`     | `InitialChoicePage`    | `features/learn`           | 无       |
| `/learn/:wordId`      | `LearnPage`            | `features/learn`           | `wordId` |
| `/kana-chart`         | `KanaChartPage`        | `features/kana/chart`      | 无       |
| `/kana-review`        | `KanaReviewPage`       | `features/kana/review`     | 无       |
| `/word-review`        | `WordReviewPage`       | `features/word_review`     | 无       |
| `/vocabulary-book`    | `VocabularyBookPage`   | `features/vocabulary_book` | 无       |
| `/statistics`         | `StatisticsPage`       | `features/statistics`      | 无       |
| `/article-list`       | `ArticleListPage`      | `features/article`         | 无       |
| `/article-detail/:id` | `ArticleDetailPage`    | `features/article`         | `id`     |
| `/grammar/list`       | `GrammarListPage`      | `features/grammar`         | 无       |
| `/grammar/learn/:id`  | `GrammarLearningPage`  | `features/grammar`         | `id`     |
| `/grammar-book`       | `GrammarBookPage`      | `features/grammar_book`    | 无       |
| `/settings`           | `SettingsPage`         | `features/settings`        | 无       |
| `/debug`              | `DebugPlaceholderPage` | `debug/pages`              | 无       |

---

## 六、路由实现示例（标准）

```dart
final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: <NavigatorObserver>[appRouteObserver],
  routes: [
    GoRoute(
      path: '/learn/:wordId',
      builder: (context, state) {
        final wordIdStr = state.pathParameters['wordId'];
        if (wordIdStr == null) {
          return const ErrorPage();
        }
        final wordId = int.parse(wordIdStr);
        return LearnPage(initialWordId: wordId);
      },
    ),
  ],
);
```

---

## 七、Router 与统计 / Session 的关系（重要）

### 明确声明（冻结）

* Router **不参与**：

  * PageDurationTracker
  * Session 生命周期
  * daily_stats 写入
  * study_logs 写入

### 页面统计规则

* 页面进入 / 离开统计：

  * 由 **页面自身**（Page + Mixin / Hook）负责
* Router 不触发任何统计事件

---

## 八、Debug 路由规则（冻结）

### Debug 路由隔离

* 所有 Debug 页面：

  * 必须在 `/debug/*` 前缀下
  * 与生产 Feature 路由完全隔离

### Debug 路由约束

* Debug 页面：

  * ❌ 不直连 Repository
  * ❌ 不直连 Database
  * ✅ 仅通过 Command / Query
* Debug Router：

  * ❌ 不注入调试逻辑
  * ❌ 不根据 build mode 改变结构

是否可访问 Debug，由 **UI 或构建配置** 决定，而非 Router。

---

## 九、明确禁止的 Router 反模式（Hard ❌）

* ❌ 在 Router 中判断：

  * 是否学习过
  * 是否有复习任务
  * 是否统计某天
* ❌ 在 Router 中触发：

  * Command
  * Session
  * Analytics
* ❌ 使用嵌套路由 / ShellRoute
* ❌ 使用 query 参数承载核心业务
* ❌ 将 Router 作为“流程控制器”

---

## 十、变更规则（封板）

> **以下任一情况 → 不允许修改 Router**

* 为“少写一行代码”
* 为“页面之间共享状态”
* 为“统计方便”
* 为“快速 Debug”

Router 只允许在 **新增页面类型** 时扩展。

---

## 🔒 最终冻结声明

> Router 是 BreezeJP 中 **最薄、最稳定的一层**。
>
> 当路由设计看起来需要“更聪明”时，
> **一定是业务层放错了位置。**
