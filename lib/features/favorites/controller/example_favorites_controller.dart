import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/commands/favorite_command.dart';
import '../../../data/commands/favorite_command_provider.dart';
import '../../../data/models/read/example_favorite_item.dart';
import '../../../data/queries/study_remote_query.dart';
import '../../../data/queries/study_remote_query_provider.dart';
import '../state/example_favorites_state.dart';

final exampleFavoritesControllerProvider =
    NotifierProvider<ExampleFavoritesController, ExampleFavoritesState>(
      ExampleFavoritesController.new,
    );

const int _kExampleFavoritesPageSize = 20;

class ExampleFavoritesController extends Notifier<ExampleFavoritesState> {
  @override
  ExampleFavoritesState build() => const ExampleFavoritesState();

  StudyRemoteQuery get _remoteQuery => ref.read(studyRemoteQueryProvider);
  FavoriteCommand get _favoriteCommand => ref.read(favoriteCommandProvider);

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final searchQuery = state.searchQuery.trim().isEmpty
          ? null
          : state.searchQuery.trim();
      final response = await _remoteQuery.fetchWordExampleFavorites(
        limit: _kExampleFavoritesPageSize,
        offset: 0,
        searchQuery: searchQuery,
      );

      state = state.copyWith(
        isLoading: false,
        items: List<ExampleFavoriteItem>.from(response.items),
        totalCount: response.totalCount,
        hasMore: response.hasMore,
      );
    } catch (e, stackTrace) {
      logger.error('例句收藏加载失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '例句收藏加载失败: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }

    try {
      state = state.copyWith(isLoadingMore: true);
      final searchQuery = state.searchQuery.trim().isEmpty
          ? null
          : state.searchQuery.trim();
      final response = await _remoteQuery.fetchWordExampleFavorites(
        limit: _kExampleFavoritesPageSize,
        offset: state.items.length,
        searchQuery: searchQuery,
      );

      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...response.items],
        hasMore: response.hasMore,
      );
    } catch (e, stackTrace) {
      logger.error('例句收藏加载更多失败', e, stackTrace);
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadInitial();
  }

  Future<void> unfavorite(ExampleFavoriteItem item) async {
    await _favoriteCommand.removeWordExampleFavorite(
      exampleId: item.exampleId,
      wordId: item.wordId,
    );
  }
}
