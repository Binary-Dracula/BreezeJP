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

  /// 统计单词已掌握数量
  Future<int> getWordMasteredCount(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM study_words
        WHERE user_id = ? AND user_state = ?
      ''',
        [userId, LearningStatus.mastered.value],
      );
      final count = (result.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'study_words',
        where:
            'user_id = $userId AND user_state = ${LearningStatus.mastered.value}',
        resultCount: 1,
      );

      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 统计假名已掌握数量
  Future<int> getKanaMasteredCount(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM kana_learning_state
        WHERE user_id = ? AND learning_status = ?
      ''',
        [userId, LearningStatus.mastered.value],
      );
      final count = (result.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_learning_state',
        where:
            'user_id = $userId AND learning_status = ${LearningStatus.mastered.value}',
        resultCount: 1,
      );

      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<int> getTotalMasteredCount(int userId) async {
    final wordCount = await getWordMasteredCount(userId);
    final kanaCount = await getKanaMasteredCount(userId);
    return wordCount + kanaCount;
  }
}
