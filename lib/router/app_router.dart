import 'package:flutter/widgets.dart';
import 'package:breeze_jp/features/kana/review/pages/kana_review_page.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/learn/pages/initial_choice_page.dart';
import '../features/learn/pages/learn_page.dart';
import '../features/kana/chart/pages/kana_chart_page.dart';
import '../features/article/pages/article_list_page.dart';
import '../features/article/pages/article_detail_page.dart';
import '../features/word_review/pages/word_review_page.dart';
import '../features/vocabulary_book/pages/vocabulary_book_page.dart';
import '../features/statistics/pages/statistics_page.dart';
import '../debug/pages/debug_placeholder_page.dart';
import 'app_route_observer.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/grammar/pages/grammar_list_page.dart';
import '../features/grammar/pages/grammar_learning_page.dart';
import '../features/grammar_book/pages/grammar_book_page.dart';
import '../features/reference/presentation/reference_screen.dart';

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
    // ----------------------------------------------------------------------
    // Word Detail
    GoRoute(
      path: '/kana-review',
      name: 'kana-review',
      builder: (context, state) => const KanaReviewPage(),
    ),
    // 复习单词页面
    GoRoute(
      path: '/word-review',
      name: 'word-review',
      builder: (context, state) => const WordReviewPage(),
    ),

    // 单词本页面
    GoRoute(
      path: '/vocabulary-book',
      name: 'vocabulary-book',
      builder: (context, state) => const VocabularyBookPage(),
    ),

    // Debug 占位入口
    GoRoute(
      path: '/debug',
      name: 'debug',
      builder: (context, state) => const DebugPlaceholderPage(),
    ),

    // 详细统计页面
    GoRoute(
      path: '/statistics',
      name: 'statistics',
      builder: (context, state) => const StatisticsPage(),
    ),

    // Reading Mode / Shadowing
    GoRoute(
      path: '/article-list',
      name: 'article-list',
      builder: (context, state) => const ArticleListPage(),
    ),
    GoRoute(
      path: '/article-detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ArticleDetailPage(articleId: id);
      },
    ),

    // Grammar List
    GoRoute(
      path: '/grammar/list',
      name: 'grammar-list',
      builder: (context, state) => const GrammarListPage(),
    ),

    // Grammar Learning
    GoRoute(
      path: '/grammar/learn/:id',
      name: 'grammar-learn',
      builder: (context, state) {
        final idStr = state.pathParameters['id'];
        final id = int.tryParse(idStr ?? '') ?? 0;
        return GrammarLearningPage(grammarId: id);
      },
    ),

    // Grammar Book
    GoRoute(
      path: '/grammar-book',
      name: 'grammar-book',
      builder: (context, state) => const GrammarBookPage(),
    ),

    // Settings
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),

    // Reference
    GoRoute(
      path: '/reference',
      name: 'reference',
      builder: (context, state) => const ReferenceScreen(),
    ),
  ],
);
