import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../../core/constants/learning_status.dart';

final masteredStateQueryProvider = Provider<MasteredStateQuery>((ref) {
  final db = ref.read(databaseProvider);
  return MasteredStateQuery(db);
});

/// 累计掌握统计查询（单词 + 假名）
class MasteredStateQuery {
  MasteredStateQuery(this._db);

  final Database _db;

  Future<int> getTotalMasteredCount(int userId) async {
    try {
      final wordResult = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM study_words
        WHERE user_id = ? AND user_state = ?
      ''',
        [userId, LearningStatus.mastered.value],
      );
      final wordCount = (wordResult.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'study_words',
        where:
            'user_id = $userId AND user_state = ${LearningStatus.mastered.value}',
        resultCount: 1,
      );

      final kanaResult = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM kana_learning_state
        WHERE user_id = ? AND learning_status = ?
      ''',
        [userId, LearningStatus.mastered.value],
      );
      final kanaCount = (kanaResult.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_learning_state',
        where:
            'user_id = $userId AND learning_status = ${LearningStatus.mastered.value}',
        resultCount: 1,
      );

      return wordCount + kanaCount;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words + kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
