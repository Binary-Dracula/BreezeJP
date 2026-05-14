import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../features/favorites/providers/favorite_refresh_provider.dart';
import 'favorite_remote_command.dart';
import 'favorite_remote_command_provider.dart';

class FavoriteCommand {
  FavoriteCommand(this.ref);

  final Ref ref;

  FavoriteRemoteCommand get _favoriteRemote =>
      ref.read(favoriteRemoteCommandProvider);
  FavoriteRefreshNotifier get _refreshNotifier =>
      ref.read(favoriteRefreshProvider.notifier);

  Future<bool> toggleWordFavorite({
    required String wordId,
    String? bookId,
  }) async {
    final result = await _favoriteRemote.toggleWordFavorite(wordId: wordId);
    _refreshNotifier.bump();
    logger.info(
      '[Favorite] ${result.favorited ? '收藏' : '取消收藏'}单词: wordId=$wordId',
    );
    return result.favorited;
  }

  Future<void> addWordFavorite({required String wordId, String? bookId}) async {
    await _ensureWordFavoriteState(wordId: wordId, favorited: true);
  }

  Future<void> removeWordFavorite({required String wordId}) async {
    await _ensureWordFavoriteState(wordId: wordId, favorited: false);
  }

  Future<bool> toggleWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    final result = await _favoriteRemote.toggleWordExampleFavorite(
      exampleId: exampleId,
      wordId: wordId,
    );
    _refreshNotifier.bump();
    logger.info(
      '[Favorite] ${result.favorited ? '收藏' : '取消收藏'}例句: exampleId=$exampleId, wordId=$wordId',
    );
    return result.favorited;
  }

  Future<void> addWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    await _ensureWordExampleFavoriteState(
      exampleId: exampleId,
      wordId: wordId,
      favorited: true,
    );
  }

  Future<void> removeWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    await _ensureWordExampleFavoriteState(
      exampleId: exampleId,
      wordId: wordId,
      favorited: false,
    );
  }

  Future<void> _ensureWordFavoriteState({
    required String wordId,
    required bool favorited,
  }) async {
    final result = await _favoriteRemote.toggleWordFavorite(wordId: wordId);
    FavoriteToggleResult finalResult = result;
    if (result.favorited != favorited) {
      finalResult = await _favoriteRemote.toggleWordFavorite(wordId: wordId);
    }

    if (finalResult.favorited != favorited) {
      throw StateError('单词收藏状态更新失败: wordId=$wordId');
    }

    _refreshNotifier.bump();
    logger.info('[Favorite] ${favorited ? '收藏' : '取消收藏'}单词: wordId=$wordId');
  }

  Future<void> _ensureWordExampleFavoriteState({
    required String exampleId,
    String? wordId,
    required bool favorited,
  }) async {
    final resolvedWordId = wordId;
    if (resolvedWordId == null || resolvedWordId.isEmpty) {
      throw StateError('缺少例句所属单词: exampleId=$exampleId');
    }

    final result = await _favoriteRemote.toggleWordExampleFavorite(
      exampleId: exampleId,
      wordId: resolvedWordId,
    );
    FavoriteToggleResult finalResult = result;
    if (result.favorited != favorited) {
      finalResult = await _favoriteRemote.toggleWordExampleFavorite(
        exampleId: exampleId,
        wordId: resolvedWordId,
      );
    }

    if (finalResult.favorited != favorited) {
      throw StateError('例句收藏状态更新失败: exampleId=$exampleId');
    }

    _refreshNotifier.bump();
    logger.info(
      '[Favorite] ${favorited ? '收藏' : '取消收藏'}例句: exampleId=$exampleId, wordId=$resolvedWordId',
    );
  }
}
