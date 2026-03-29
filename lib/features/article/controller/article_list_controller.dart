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

  /// 加载文章列表：先检查登录态，再增量同步，最后读本地缓存
  Future<void> loadArticles() async {
    state = state.copyWith(isLoading: true, error: null, needsLogin: false);

    // 未登录：展示登录引导，不加载内容
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      state = state.copyWith(isLoading: false, needsLogin: true);
      return;
    }

    // 增量同步
    try {
      state = state.copyWith(isSyncing: true);
      await ref.read(articleSyncCommandProvider).syncArticles();
    } catch (e) {
      // 同步失败不阻断，允许展示本地缓存
    } finally {
      state = state.copyWith(isSyncing: false);
    }

    // 读取本地缓存
    try {
      final articles = await ref.read(articleQueryProvider).getArticles();
      state = state.copyWith(articles: articles, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
