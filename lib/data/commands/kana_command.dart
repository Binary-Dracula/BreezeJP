import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/kana/kana_domain_event.dart';
import '../models/kana_learning_state.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kana_repository_provider.dart';

/// Kana command layer (state updates only).
class KanaCommand {
  KanaCommand(this.ref);

  final Ref ref;

  KanaRepository get _repo => ref.read(kanaRepositoryProvider);

  /// Create kana learning state when first practiced.
  Future<KanaPracticed?> onKanaPracticed({
    required int userId,
    required int kanaId,
  }) async {
    try {
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing != null) return null;

      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final state = KanaLearningState(
        id: 0,
        userId: userId,
        kanaId: kanaId,
        learningStatus: LearningStatus.learning,
        createdAt: nowSeconds,
        updatedAt: nowSeconds,
      );
      await _repo.insertKanaLearningState(state);
      return KanaPracticed(
        userId: userId,
        kanaId: kanaId,
        occurredAt: now,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Toggle kana status between learning and mastered.
  Future<KanaDomainEvent?> toggleKanaMastered({
    required int userId,
    required int kanaId,
  }) async {
    try {
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing == null) {
        final state = KanaLearningState(
          id: 0,
          userId: userId,
          kanaId: kanaId,
          learningStatus: LearningStatus.mastered,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _repo.insertKanaLearningState(state);
        return KanaMastered(
          userId: userId,
          kanaId: kanaId,
          occurredAt: now,
        );
      }

      if (existing.learningStatus == LearningStatus.mastered) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.learning,
          updatedAt: nowSeconds,
        );
        await _repo.updateKanaLearningState(updated);
        return KanaUnmastered(
          userId: userId,
          kanaId: kanaId,
          occurredAt: now,
        );
      }

      if (existing.learningStatus == LearningStatus.learning) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.mastered,
          updatedAt: nowSeconds,
        );
        await _repo.updateKanaLearningState(updated);
        return KanaMastered(
          userId: userId,
          kanaId: kanaId,
          occurredAt: now,
        );
      }
      return null;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
