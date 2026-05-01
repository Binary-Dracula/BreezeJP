import '../../../data/models/read/example_favorite_item.dart';

class ExampleFavoritesState {
  const ExampleFavoritesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.items = const [],
    this.totalCount = 0,
    this.searchQuery = '',
  });

  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final List<ExampleFavoriteItem> items;
  final int totalCount;
  final String searchQuery;

  ExampleFavoritesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    List<ExampleFavoriteItem>? items,
    int? totalCount,
    String? searchQuery,
  }) {
    return ExampleFavoritesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
