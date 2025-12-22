import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/kana_repository.dart';
import '../../repositories/kana_repository_provider.dart';

/// Debug kana command (destructive cleanup only).
class DebugKanaCommand {
  DebugKanaCommand(this._ref);

  final Ref _ref;

  KanaRepository get _repo => _ref.read(kanaRepositoryProvider);

  /// Clear user's kana review data (logs + learning states).
  Future<void> clearUserReviewData({required int userId}) async {
    await _repo.deleteKanaLogsByUser(userId);
    await _repo.deleteKanaLearningStatesByUser(userId);
  }
}
