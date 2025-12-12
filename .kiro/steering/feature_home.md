---
inclusion: always
---

# Home Feature 实现指南

## 概述

Home Feature 是 BreezeJP 的核心入口页面，实现了产品需求文档中定义的 Dashboard 设计。采用 MVVM + Repository + Riverpod 架构模式，提供学习控制中心功能。

## 文件结构

```
lib/features/home/
├── controller/
│   └── home_controller.dart     # 业务逻辑控制器
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
- `streakDays`: 连续学习天数
- `masteredWordCount`: 累计掌握单词数
- `todayStudyDurationMinutes`: 今日学习时长（分钟）
- `isInitialized`: 数据初始化状态

**计算属性**：
- `hasTask`: 是否有学习任务（复习或新词）
- `hasError`: 是否有错误
- `hasData`: 是否已初始化数据

### 2. HomeController（业务逻辑）

**职责**：处理主页数据加载、刷新和错误处理

**核心方法**：
- `loadHomeData()`: 加载主页所有数据
  - 获取当前活跃用户信息
  - 统计待复习单词数量
  - 获取用户学习统计数据
  - 计算连续学习天数
  - 获取今日学习时长
- `refresh()`: 刷新数据
- `clearError()`: 清空错误状态

**依赖注入**：
- `StudyWordRepository`: 单词学习数据
- `DailyStatRepository`: 每日统计数据
- `activeUserProvider`: 当前用户信息

### 3. HomePage（UI 实现）

**职责**：渲染主页 UI，响应用户交互

**页面结构**：
1. **Header（顶部区域）**
   - 时间问候语（早上好/下午好/晚上好）
   - 用户昵称显示
   - 设置按钮
   - Debug 模式下的调试入口

2. **Primary Actions（学习主入口）**
   - 学习新单词卡片：渐变背景，引导用户进入语义分支学习
   - 学习五十音图卡片：独立入口，基础发音学习

3. **Review Section（复习模块）**
   - 复习单词卡片：显示待复习数量，支持点击进入
   - 复习五十音卡片：预留接口，当前显示 0

4. **Stats Card（学习统计）**
   - 今日学习、今日复习、今日时长
   - 累计掌握、连续学习天数
   - 新用户友好提示

5. **Tools Grid（工具区）**
   - 单词本、详细统计、更多工具
   - 网格布局，预留扩展空间

## UI 设计特点

### 视觉风格
- **背景色**：`Color(0xFFF6F7FB)` 浅灰背景
- **卡片设计**：圆角 20px，轻微阴影
- **渐变色彩**：Primary Actions 使用渐变背景增强视觉吸引力
- **图标系统**：Material Icons，配色与功能语义匹配

### 交互体验
- **下拉刷新**：支持 RefreshIndicator
- **加载状态**：首次加载显示 CircularProgressIndicator
- **错误处理**：显示错误信息和重试按钮
- **新用户引导**：根据 `isNewUser` 状态调整文案

### 响应式布局
- **Primary Actions**：左右并列，等宽布局
- **Review Section**：垂直堆叠，全宽卡片
- **Stats Card**：Wrap 布局，自适应换行
- **Tools Grid**：2 列网格，固定宽高比 1.2

## 自定义组件

### _PrimaryActionCard
- **用途**：学习主入口的渐变卡片
- **特性**：渐变背景、图标、标题、副标题、行动按钮
- **交互**：InkWell 点击效果，阴影增强

### _ReviewCard
- **用途**：复习模块的功能卡片
- **特性**：根据待办数量调整视觉状态
- **布局**：图标 + 文本 + 数量徽章

### _StatTile
- **用途**：统计数据的小卡片
- **特性**：图标 + 标签 + 数值，固定宽度 150px
- **样式**：浅灰背景，圆角边框

## 数据流

```
HomePage (initState)
    ↓
HomeController.loadHomeData()
    ↓
[并行获取数据]
├── activeUserProvider → 用户信息
├── StudyWordRepository → 复习数量、学习统计
└── DailyStatRepository → 连续天数、今日时长
    ↓
HomeState.copyWith() → 更新状态
    ↓
HomePage (rebuild) → UI 更新
```

## 路由集成

**当前路由**：`/home`（推测，未在代码中明确定义）

**导航目标**：
- `/initial-choice`: 学习新单词入口
- `/kana-chart`: 五十音图学习
- 设置页面：TODO 待实现
- 单词本页面：TODO 待实现
- 统计详情页面：TODO 待实现

## 国际化支持

**使用 AppLocalizations**：
- `greetingMorning/Afternoon/Evening`: 时间问候语
- `userGreeting(userName)`: 用户问候
- `homeWelcome`: 欢迎文案
- `homeSubtitle`: 副标题
- `startLearning`: 开始学习按钮
- `retryButton`: 重试按钮
- `wordBook/wordBookSubtitle`: 单词本相关
- `detailedStats/detailedStatsSubtitle`: 统计相关

## 待完成功能（TODOs）

1. **设置页面跳转**：Header 设置按钮点击事件
2. **单词本页面**：Tools Grid 中的单词本入口
3. **统计详情页面**：Tools Grid 中的详细统计入口
4. **五十音复习逻辑**：当前硬编码为 0，需要接入实际数据
5. **复习功能跳转**：Review Cards 的点击事件实现

## 性能优化

- **懒加载**：使用 `addPostFrameCallback` 延迟数据加载
- **状态缓存**：通过 `isInitialized` 避免重复加载
- **错误恢复**：提供重试机制，不阻塞用户操作
- **下拉刷新**：支持手动刷新数据

## 调试支持

- **Debug 模式**：显示 Debug 按钮，跳转到 `DebugSrsPage`
- **日志记录**：使用 `logger` 记录关键操作和错误
- **错误展示**：开发阶段显示详细错误信息

## 设计原则遵循

✅ **学习入口优先**：Primary Actions 位于页面顶部，视觉突出  
✅ **复习模块独立**：Review Section 独立区域，不与学习入口混淆  
✅ **五十音模块独立**：与单词学习并行，独立入口和复习  
✅ **空状态友好**：新用户看到引导文案而非空数据  
✅ **成就反馈及时**：Stats Card 提供即时的学习反馈  
✅ **不追踪学习进度**：保持心流体验，无进度条或任务列表  
✅ **可扩展性高**：Tools Grid 预留未来功能扩展空间