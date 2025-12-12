---
inclusion: always
---

# 路由系统实现指南

## 概述

BreezeJP 使用 `go_router ^17.0.0` 实现声明式路由管理。路由配置集中在 `lib/router/app_router.dart`，支持参数传递、命名路由和类型安全的导航。

## 路由配置

### 核心配置
```dart
final appRouter = GoRouter(
  initialLocation: '/splash',  // 应用启动时的初始路由
  routes: [...],              // 路由定义列表
);
```

### 初始路由
- **启动页面**：`/splash`
- **设计理念**：应用启动时先显示 Splash 页面，完成初始化后跳转到主页

## 路由定义

### 1. Splash 页面
```dart
GoRoute(
  path: '/splash',
  name: 'splash',
  builder: (context, state) => const SplashPage(),
)
```
- **用途**：应用启动页面，处理初始化逻辑
- **特点**：无参数，静态页面
- **导航**：通常自动跳转到 `/home`

### 2. 主页面（Dashboard）
```dart
GoRoute(
  path: '/home',
  name: 'home',
  builder: (context, state) => const HomePage(),
)
```
- **用途**：BreezeJP 的核心控制中心
- **特点**：学习入口、复习模块、统计展示
- **导航目标**：作为其他功能的入口枢纽

### 3. 初始选择页面
```dart
GoRoute(
  path: '/initial-choice',
  name: 'initial-choice',
  builder: (context, state) => const InitialChoicePage(),
)
```
- **用途**：语义分支学习模式的入口页面
- **功能**：用户选择学习起点，开始语义关联学习
- **导航来源**：主页的"学习新单词"按钮

### 4. 学习页面（参数化路由）
```dart
GoRoute(
  path: '/learn/:wordId',
  name: 'learn',
  builder: (context, state) {
    final wordIdStr = state.pathParameters['wordId'];
    final wordId = int.tryParse(wordIdStr ?? '') ?? 0;
    return LearnPage(initialWordId: wordId);
  },
)
```
- **用途**：单词学习的核心页面
- **参数**：`:wordId` - 要学习的单词 ID
- **参数处理**：
  - 从 `state.pathParameters['wordId']` 获取字符串
  - 使用 `int.tryParse()` 转换为整数
  - 默认值为 0（解析失败时）
- **特点**：支持左右滑动切换单词，沉浸式学习体验

### 5. 五十音图页面
```dart
GoRoute(
  path: '/kana-chart',
  name: 'kana-chart',
  builder: (context, state) => const KanaChartPage(),
)
```
- **用途**：五十音图学习页面
- **功能**：假名学习、笔顺练习、发音训练
- **导航来源**：主页的"学习五十音图"按钮

### 6. 五十音复习页面
```dart
GoRoute(
  path: '/matching_page',
  name: 'matching_page',
  builder: (context, state) => const MatchingPage(),
)
```
- **用途**：五十音复习功能页面
- **功能**：假名复习、匹配练习
- **特点**：独立的复习模式，与单词复习并行

## 导航模式

### 基础导航
```dart
// 跳转到指定路由
context.go('/home');

// 带参数跳转
context.go('/learn/123');  // wordId = 123

// 使用命名路由
context.goNamed('home');
context.goNamed('learn', pathParameters: {'wordId': '123'});
```

### 栈管理
```dart
// 返回上一页
context.pop();

// 替换当前路由（不保留历史）
context.replace('/home');

// 推入新页面（保留历史栈）
context.push('/kana-chart');
```

### 参数传递
```dart
// 路径参数（URL 中的参数）
context.go('/learn/456');  // wordId 通过 URL 传递

// 额外数据传递（通过 extra 参数）
context.go('/word-detail', extra: wordObject);
```

## 路由架构特点

### 1. 扁平化结构
- **设计理念**：避免深层嵌套，保持路由简洁
- **优势**：易于理解和维护，符合移动应用导航习惯
- **实现**：所有路由都在根级别定义

### 2. 功能模块对应
```
/splash         → features/splash/
/home           → features/home/
/initial-choice → features/learn/
/learn/:wordId  → features/learn/
/kana-chart     → features/kana/chart/
/matching_page  → features/kana/review/
```

### 3. 参数化支持
- **动态路由**：`/learn/:wordId` 支持不同单词的学习
- **类型安全**：参数解析包含错误处理和默认值
- **扩展性**：易于添加更多参数化路由

## 导航流程

### 典型用户路径
```
启动应用 → /splash
    ↓
初始化完成 → /home
    ↓
选择学习 → /initial-choice
    ↓
开始学习 → /learn/:wordId
    ↓
返回主页 → /home
```

### 五十音学习路径
```
主页 → /home
    ↓
选择五十音 → /kana-chart
    ↓
复习假名 → /matching_page
    ↓
返回主页 → /home
```

## 路由守卫与中间件

### 当前实现
- **无认证守卫**：当前版本无需登录验证
- **无权限控制**：所有路由均可直接访问
- **简化设计**：符合 MVP 阶段的产品需求

### 未来扩展
- **用户认证**：可添加登录状态检查
- **权限控制**：Pro 功能的访问限制
- **数据预加载**：路由切换时的数据准备

## 错误处理

### 参数解析错误
```dart
final wordId = int.tryParse(wordIdStr ?? '') ?? 0;
```
- **策略**：解析失败时使用默认值 0
- **用户体验**：不会因参数错误导致应用崩溃
- **日志记录**：建议添加错误日志记录

### 路由不存在
- **go_router 默认行为**：显示 404 页面
- **改进建议**：可自定义错误页面，引导用户返回主页

## 性能优化

### 懒加载
- **页面构建**：使用 `builder` 函数实现懒加载
- **内存管理**：页面仅在需要时创建
- **导航性能**：避免预加载不必要的页面

### 路由缓存
- **go_router 内置**：自动管理路由栈和页面状态
- **状态保持**：支持页面状态在导航时保持

## 调试支持

### 路由日志
```dart
// 建议添加路由变化日志
GoRouter(
  debugLogDiagnostics: true,  // 开发模式下启用
  // ...
);
```

### 开发工具
- **Flutter Inspector**：可视化路由栈
- **go_router 调试**：内置的路由状态检查

## 与产品设计的对应

### Dashboard 中心化
- **路由设计**：`/home` 作为核心枢纽
- **导航模式**：其他页面通过主页进入
- **用户体验**：符合"单页 Dashboard"的产品理念

### 学习流程支持
- **语义分支**：`/initial-choice` → `/learn/:wordId` 的流程
- **五十音独立**：`/kana-chart` 和 `/matching_page` 的并行设计
- **参数传递**：支持学习状态的连续性

## 待完成功能

基于 home feature 中的 TODOs，以下路由需要添加：

1. **设置页面**：`/settings`
2. **单词本页面**：`/word-book`
3. **统计详情页面**：`/stats`
4. **单词详情页面**：`/word-detail/:wordId`
5. **复习模式页面**：`/review/words` 和 `/review/kana`

## 最佳实践

### 1. 命名规范
- **路径**：使用 kebab-case（如 `/initial-choice`）
- **名称**：与路径保持一致（如 `name: 'initial-choice'`）
- **参数**：使用 camelCase（如 `wordId`）

### 2. 参数处理
- **类型转换**：始终包含错误处理
- **默认值**：提供合理的默认值
- **验证**：在页面中验证参数有效性

### 3. 导航调用
- **优先使用**：`context.go()` 用于主要导航
- **栈管理**：`context.push()` 用于临时页面
- **返回处理**：`context.pop()` 用于返回操作

### 4. 路由组织
- **模块对应**：路由与 feature 目录结构保持一致
- **扁平结构**：避免过深的路由嵌套
- **语义清晰**：路径名称要能清楚表达页面功能