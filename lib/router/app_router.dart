import 'package:flutter/widgets.dart';
import 'package:breeze_jp/features/kana/review/pages/matching_page.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/learn/pages/initial_choice_page.dart';
import '../features/learn/pages/learn_page.dart';
import '../features/kana/chart/pages/kana_chart_page.dart';
import '../debug/pages/debug_page.dart';
import '../debug/pages/debug_statistics_page.dart';
import '../debug/pages/tests/debug_kana_review_data_generator_page.dart';
import '../debug/pages/tests/debug_srs_test_page.dart';
import 'app_route_observer.dart';

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: <NavigatorObserver>[appRouteObserver],
  routes: [
    // Splash 页面
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),

    // 主页面
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // 初始选择页面（语义分支学习模式入口）
    GoRoute(
      path: '/initial-choice',
      name: 'initial-choice',
      builder: (context, state) => const InitialChoicePage(),
    ),

    // 学习页面（带单词 ID 参数）
    GoRoute(
      path: '/learn/:wordId',
      name: 'learn',
      builder: (context, state) {
        final wordIdStr = state.pathParameters['wordId'];
        final wordId = int.tryParse(wordIdStr ?? '') ?? 0;
        return LearnPage(initialWordId: wordId);
      },
    ),

    // 五十音图页面
    GoRoute(
      path: '/kana-chart',
      name: 'kana-chart',
      builder: (context, state) => const KanaChartPage(),
    ),
    // 复习五十音图页面
    GoRoute(
      path: '/matching_page',
      name: 'matching_page',
      builder: (context, state) => const MatchingPage(),
    ),

    // Debug 工具（仅开发用途）
    GoRoute(
      path: '/debug',
      name: 'debug',
      builder: (context, state) => const DebugPage(),
    ),
    GoRoute(
      path: '/debug/statistics',
      name: 'debug-statistics',
      builder: (context, state) => const DebugStatisticsPage(),
    ),
    GoRoute(
      path: '/debug/srs',
      name: 'debug-srs',
      builder: (context, state) => const DebugSrsTestPage(),
    ),
    GoRoute(
      path: '/debug/kana-review-data',
      name: 'debug-kana-review-data',
      builder: (context, state) => const DebugKanaReviewDataGeneratorPage(),
    ),
  ],
);
