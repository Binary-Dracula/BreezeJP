import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../features/favorites/providers/favorite_refresh_provider.dart';
import '../models/word_example_favorite.dart';
import '../models/word_favorite.dart';
import '../queries/favorite_query.dart';
import '../queries/favorite_query_provider.dart';
import '../repositories/word_example_favorite_repository.dart';
import '../repositories/word_example_favorite_repository_provider.dart';
import '../repositories/word_favorite_repository.dart';
import '../repositories/word_favorite_repository_provider.dart';
import 'active_user_command.dart';
import 'active_user_command_provider.dart';
import 'sync_remote_command.dart';

class FavoriteCommand {
  FavoriteCommand(this.ref);

  final Ref ref;

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  FavoriteQuery get _favoriteQuery => ref.read(favoriteQueryProvider);
  WordFavoriteRepository get _wordFavoriteRepo =>
      ref.read(wordFavoriteRepositoryProvider);
  WordExampleFavoriteRepository get _wordExampleFavoriteRepo =>
      ref.read(wordExampleFavoriteRepositoryProvider);
  SyncRemoteCommand get _syncRemote => ref.read(syncRemoteCommandProvider);
  FavoriteRefreshNotifier get _refreshNotifier =>
      ref.read(favoriteRefreshProvider.notifier);

  Future<bool> toggleWordFavorite({
    required String wordId,
    String? bookId,
  }) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final existing = await _wordFavoriteRepo.getFavorite(user.id, wordId);
    if (existing != null) {
      await removeWordFavorite(wordId: wordId);
      return false;
    }

    await addWordFavorite(wordId: wordId, bookId: bookId);
    return true;
  }

  Future<void> addWordFavorite({required String wordId, String? bookId}) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final resolvedBookId =
        bookId ?? await _favoriteQuery.resolveBookIdForWord(wordId);
    if (resolvedBookId == null || resolvedBookId.isEmpty) {
      throw StateError('未找到单词所属词书: $wordId');
    }

    final existing = await _wordFavoriteRepo.getFavorite(user.id, wordId);
    final now = DateTime.now();
    final favorite = WordFavorite(
      id: existing?.id ?? 0,
      userId: user.id,
      wordId: wordId,
      bookId: resolvedBookId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _wordFavoriteRepo.saveFavorite(favorite);
    _refreshNotifier.bump();
    _syncRemote.scheduleCheckpoint();

    logger.info('[Favorite] 收藏单词: wordId=$wordId, bookId=$resolvedBookId');
  }

  Future<void> removeWordFavorite({required String wordId}) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final existing = await _wordFavoriteRepo.getFavorite(user.id, wordId);
    if (existing == null) {
      return;
    }

    await _wordFavoriteRepo.deleteFavorite(user.id, wordId);
    _refreshNotifier.bump();
    _syncRemote.scheduleCheckpoint();

    logger.info('[Favorite] 取消收藏单词: wordId=$wordId');
  }

  Future<bool> toggleWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final existing = await _wordExampleFavoriteRepo.getFavorite(
      user.id,
      exampleId,
    );
    if (existing != null) {
      await removeWordExampleFavorite(exampleId: exampleId);
      return false;
    }

    await addWordExampleFavorite(exampleId: exampleId, wordId: wordId);
    return true;
  }

  Future<void> addWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final existing = await _wordExampleFavoriteRepo.getFavorite(
      user.id,
      exampleId,
    );
    final now = DateTime.now();
    final favorite = WordExampleFavorite(
      id: existing?.id ?? 0,
      userId: user.id,
      exampleId: exampleId,
      wordId: wordId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _wordExampleFavoriteRepo.saveFavorite(favorite);
    _refreshNotifier.bump();
    _syncRemote.scheduleCheckpoint();

    logger.info('[Favorite] 收藏例句: exampleId=$exampleId, wordId=$wordId');
  }

  Future<void> removeWordExampleFavorite({required String exampleId}) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final existing = await _wordExampleFavoriteRepo.getFavorite(
      user.id,
      exampleId,
    );
    if (existing == null) {
      return;
    }

    await _wordExampleFavoriteRepo.deleteFavorite(user.id, exampleId);
    _refreshNotifier.bump();
    _syncRemote.scheduleCheckpoint();

    logger.info('[Favorite] 取消收藏例句: exampleId=$exampleId');
  }
}
