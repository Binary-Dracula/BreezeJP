import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:breeze_jp/features/kana/review/pages/kana_review_page.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/change_password_page.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/learn/pages/learn_page.dart';
import '../features/kana/chart/pages/kana_chart_page.dart';
import '../features/article/pages/article_list_page.dart';
import '../features/article/pages/article_detail_page.dart';
import '../features/word_review/pages/word_review_page.dart';
import '../features/vocabulary_book/pages/vocabulary_book_page.dart';
import '../features/word_detail/pages/word_detail_page.dart';
import '../features/book_selection/pages/book_selection_page.dart';
import '../debug/pages/debug_placeholder_page.dart';
import 'app_route_observer.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/grammar/pages/grammar_list_page.dart';
import '../features/grammar/pages/grammar_learning_page.dart';
import '../features/grammar_book/pages/grammar_book_page.dart';
import '../features/kana/stroke/pages/kana_stroke_practice_page.dart';
import '../data/models/kana_detail.dart';
import '../features/kana/chart/state/kana_chart_state.dart';
import '../features/reference/pages/reference_page.dart';

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh()
    : _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        _,
      ) {
        instance.notifyListeners();
      });

  static final _AuthRouterRefresh instance = _AuthRouterRefresh._();

  _AuthRouterRefresh._()
    : _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        _,
      ) {
        instance.notifyListeners();
      });

  final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

bool _isPublicRoute(String location) {
  const publicPrefixes = {
    '/splash',
    '/login',
    '/register',
    '/home',
    '/kana-chart',
    '/kana-stroke',
    '/settings',
    '/reference',
  };

  return publicPrefixes.any(
    (prefix) => location == prefix || location.startsWith('$prefix/'),
  );
}

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: <NavigatorObserver>[appRouteObserver],
  refreshListenable: _AuthRouterRefresh.instance,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.uri.path;

    if (!isLoggedIn && !_isPublicRoute(location)) {
      return '/login';
    }

    if (isLoggedIn && (location == '/login' || location == '/register')) {
      return '/home';
    }

    return null;
  },
  routes: [
    // Splash 页面
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),

    // 登录页面
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // 注册页面
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),

    // 修改密码页
    GoRoute(
      path: '/change-password',
      name: 'change-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),

    // 主页面
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // 学习页面（书籍 ID 参数）
    GoRoute(
      path: '/learn/:bookId',
      name: 'learn',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        return LearnPage(bookId: bookId);
      },
    ),

    // 五十音图页面
    GoRoute(
      path: '/kana-chart',
      name: 'kana-chart',
      builder: (context, state) => const KanaChartPage(),
    ),

    // 假名笔顺练习页面
    GoRoute(
      path: '/kana-stroke',
      name: 'kana-stroke',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return KanaStrokePracticePage(
          kanaLetters: extra['kanaLetters'] as List<KanaLetterWithState>,
          initialIndex: extra['initialIndex'] as int,
          displayMode: extra['displayMode'] as KanaDisplayMode,
        );
      },
    ),
    // 单词详情页
    GoRoute(
      path: '/word-detail/:id',
      name: 'word-detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return WordDetailPage(wordId: id);
      },
    ),

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

    // 辞书选择页面
    GoRoute(
      path: '/book-selection',
      name: 'book-selection',
      builder: (context, state) => const BookSelectionPage(),
    ),
    GoRoute(
      path: '/book-selection/settings',
      name: 'book-selection-settings',
      builder: (context, state) =>
          const BookSelectionPage(navigateToLearnOnSelect: false),
    ),

    // Debug 占位入口
    GoRoute(
      path: '/debug',
      name: 'debug',
      builder: (context, state) => const DebugPlaceholderPage(),
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

    // Settings 及其子路由
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        // 个人资料页
        GoRoute(
          path: 'profile',
          name: 'profile',
          builder: (context, state) => const ProfilePage(),
          routes: [
            // 修改密码页
            GoRoute(
              path: 'change-password',
              name: 'profile-change-password',
              builder: (context, state) => const ChangePasswordPage(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/reference',
      name: 'reference',
      builder: (context, state) => const ReferencePage(),
    ),
  ],
);
