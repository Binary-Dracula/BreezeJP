---
inclusion: always
---

# 路由系统实现指南

## 概述

BreezeJP 使用 `go_router ^17.0.0` 实现声明式路由管理。路由配置集中在 `lib/router/app_router.dart`，并挂载 `app_route_observer` 作为观察器。

## 路由配置

```dart
final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: <NavigatorObserver>[appRouteObserver],
  routes: [...],
);
```

## 路由定义（当前实现）

### Splash 页面

- 路由：`/splash`
- 页面：`SplashPage`

### 主页面（Dashboard）

- 路由：`/home`
- 页面：`HomePage`

### 初始选择页面

- 路由：`/initial-choice`
- 页面：`InitialChoicePage`

### 学习页面（参数化）

- 路由：`/learn/:wordId`
- 页面：`LearnPage(initialWordId: wordId)`
- 参数解析：`state.pathParameters['wordId']`

### 五十音图页面

- 路由：`/kana-chart`
- 页面：`KanaChartPage`

### 五十音复习页面

- 路由：`/matching_page`
- 页面：`MatchingPage`

### Debug 页面

- 路由：`/debug`
- 页面：`DebugPage`

### Debug - SRS 测试

- 路由：`/debug/srs`
- 页面：`DebugSrsTestPage`

### Debug - 假名复习数据生成

- 路由：`/debug/kana-review-data`
- 页面：`DebugKanaReviewDataGeneratorPage`

## 导航示例

```dart
context.go('/home');
context.go('/learn/123');
context.goNamed('learn', pathParameters: {'wordId': '123'});
context.pop();
context.replace('/home');
```

## 路由映射

```
/splash               → features/splash/
/home                 → features/home/
/initial-choice       → features/learn/
/learn/:wordId        → features/learn/
/kana-chart           → features/kana/chart/
/matching_page        → features/kana/review/
/debug                → debug/pages/
/debug/srs            → debug/pages/tests/
/debug/kana-review-data → debug/pages/tests/
```
