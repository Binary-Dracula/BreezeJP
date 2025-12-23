---
inclusion: always
---

# Home Feature 实现指南

## 概述

Home Feature 是 BreezeJP 的核心入口页面，实现 Dashboard 设计。采用 **MVVM + Command/Query/Analytics + Riverpod** 架构，所有数据读取通过 Query/Analytics，用户状态确保通过 ActiveUserCommand。

## 文件结构

```
lib/features/home/
├── controller/
│   └── home_controller.dart     # 流程编排控制器
├── pages/
│   └── home_page.dart          # UI 页面实现
└── state/
    └── home_state.dart         # 不可变状态定义
```

## 核心组件

### 1. HomeState（状态管理）

**职责**：定义主页所有状态数据的不可变容器

**关键字段**：

- `isLoading`: 加载状态
- `error`: 错误信息
- `userName`: 用户昵称
- `reviewCount`: 待复习单词数量
- `newWordCount`: 新学单词数量
- `kanaReviewCount`: 待复习假名数量
- `streakDays`: 连续学习天数
- `masteredWordCount`: 累计掌握单词数
- `todayStudyDurationMinutes`: 今日学习时长（分钟）
- `isInitialized`: 数据初始化状态

**计算属性**：

- `hasTask`: 是否有学习任务（复习或新词）
- `hasError`: 是否有错误
- `hasData`: 是否已初始化数据

### 2. HomeController（流程编排）

**职责**：加载主页数据、刷新与错误处理

**核心方法**：

- `loadHomeData()`
- `refresh()`
- `clearError()`

**依赖注入**（当前实现）：

- `ActiveUserCommand` / `ActiveUserQuery`
- `StudyWordQuery` / `StudyWordAnalytics`
- `DailyStatQuery`
- `KanaQuery`

### 3. HomePage（UI 实现）

**职责**：渲染主页 UI，响应用户交互

**页面结构**：

1. Header（顶部区域）
2. Primary Actions（学习主入口）
3. Review Section（复习模块）
4. Stats Card（学习统计）
5. Tools Grid（工具区）

## 数据流

```
HomePage
  ↓
HomeController.loadHomeData()
  ├─ ActiveUserCommand.ensureActiveUser()
  ├─ ActiveUserQuery.getActiveUser()
  ├─ StudyWordQuery.getDueReviewCount(userId)
  ├─ KanaQuery.countDueKanaReviews(userId)
  ├─ StudyWordAnalytics.getUserStatistics(userId)
  └─ DailyStatQuery.calculateStreak(userId)
      + DailyStatQuery.getDailyStatsByDateRange(...)
  ↓
HomeState.copyWith() → UI 更新
```

## UI 设计特点

### 视觉风格

- 背景色：`Color(0xFFF6F7FB)`
- 卡片：圆角 20px，轻微阴影
- 主入口卡片使用渐变背景

### 交互体验

- 下拉刷新：`RefreshIndicator`
- 加载状态：首屏显示加载态
- 错误处理：显示错误信息并支持重试

### 响应式布局

- Primary Actions：左右并列等宽布局
- Review Section：垂直堆叠
- Stats Card：Wrap 布局
- Tools Grid：2 列网格

## 国际化支持

通过 `AppLocalizations` 获取所有展示文本：

- `homeWelcome` / `homeSubtitle`
- `startLearning` / `retry`
- `homeTodayGoal` / `homeReview` / `homeNewWords`

## 调试支持

Debug 模式下可显示调试入口，并通过路由跳转到 Debug 页面。
