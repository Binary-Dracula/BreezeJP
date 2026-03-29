import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../data/commands/article_sync_command_provider.dart';
import '../../../data/queries/article_query_provider.dart';
import '../state/article_list_state.dart';

/// 文章列表控制器 Provider
final articleListControllerProvider =
    NotifierProvider<ArticleListController, ArticleListState>(
      ArticleListController.new,
    );

/// 文章列表控制器
class ArticleListController extends Notifier<ArticleListState> {
  @override
  ArticleListState build() {
    // 监听登录状态变化：用户登录后自动重新加载
    ref.listen(isLoggedInProvider, (previous, next) {
      if (previous != next) {
        loadArticles();
      }
    });
    Future.microtask(loadArticles);
    return const ArticleListState();
  }

  /// 加载文章列表：本地优先。
  ///
  /// - 本地有数据：立即显示；后台静默同步（不刷新当次 UI）
  /// - 本地无数据：等待同步完成后再读库显示（首次安装体验）
  Future<void> loadArticles() async {
    state = state.copyWith(
      isLoading: true,
      isSyncing: false,
      error: null,
      needsLogin: false,
    );

    // 未登录：展示登录引导，不加载内容
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      state = state.copyWith(isLoading: false, needsLogin: true);
      return;
    }

    // 先读取本地缓存
    try {
      final localArticles = await ref.read(articleQueryProvider).getArticles();

      // 有本地数据：立即展示，并后台静默刷新数据库（本次不刷新 UI）
      if (localArticles.isNotEmpty) {
        state = state.copyWith(
          articles: localArticles,
          isLoading: false,
          isSyncing: false,
          error: null,
        );
        _silentRefreshArticles();
        return;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
      );
      return;
    }

    // 本地无数据：等待 API 同步完成后，再读取数据库展示
    try {
      state = state.copyWith(isSyncing: true);
      await ref.read(articleSyncCommandProvider).syncArticles();
      final articles = await ref.read(articleQueryProvider).getArticles();
      state = state.copyWith(
        articles: articles,
        isLoading: false,
        isSyncing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  /// 后台静默刷新数据库，不影响当前 UI 数据
  void _silentRefreshArticles() {
    Future<void>(() async {
      try {
        await ref.read(articleSyncCommandProvider).syncArticles();
      } catch (_) {
        // 静默失败：保留当前列表展示，不打断用户
      }
    });
  }
}
