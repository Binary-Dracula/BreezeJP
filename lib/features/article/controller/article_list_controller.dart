import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // 异步加载数据
    Future.microtask(loadArticles);
    return const ArticleListState();
  }

  /// 加载文章列表
  Future<void> loadArticles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final articleQuery = ref.read(articleQueryProvider);
      final articles = await articleQuery.getArticles();
      state = state.copyWith(articles: articles, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
