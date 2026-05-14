import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../data/queries/article_remote_query_provider.dart';
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

  /// 加载文章列表：直接从远端 API 获取。
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

    try {
      final response = await ref
          .read(articleRemoteQueryProvider)
          .fetchArticles();
      state = state.copyWith(
        articles: response.data,
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
}
