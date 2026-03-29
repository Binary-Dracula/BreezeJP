import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../data/models/article/article_summary.dart';

part 'article_list_state.freezed.dart';

@freezed
abstract class ArticleListState with _$ArticleListState {
  const factory ArticleListState({
    @Default([]) List<ArticleSummary> articles,
    @Default(true) bool isLoading,
    @Default(false) bool isSyncing,
    @Default(false) bool needsLogin,
    String? error,
  }) = _ArticleListState;
}
