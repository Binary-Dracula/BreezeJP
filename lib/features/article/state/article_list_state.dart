import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../data/models/article/article.dart';

part 'article_list_state.freezed.dart';

@freezed
abstract class ArticleListState with _$ArticleListState {
  const factory ArticleListState({
    @Default([]) List<Article> articles,
    @Default(true) bool isLoading,
    String? error,
  }) = _ArticleListState;
}
