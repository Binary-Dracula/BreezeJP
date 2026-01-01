import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import 'active_user_query.dart';
import 'active_user_query_provider.dart';

final debugStudyWordsQueryProvider = Provider<DebugStudyWordsQuery>((ref) {
  final db = ref.read(databaseProvider);
  final activeUserQuery = ref.read(activeUserQueryProvider);
  return DebugStudyWordsQuery(db, activeUserQuery);
});

class DebugStudyWordItem {
  final int wordId;
  final String word;
  final String? kana;
  final int userState;
  final DateTime? nextReviewAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebugStudyWordItem({
    required this.wordId,
    required this.word,
    required this.kana,
    required this.userState,
    required this.nextReviewAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get stateLabel => LearningStatus.fromValue(userState).name;

  String get displayWord {
    final kanaText = kana ?? '';
    if (kanaText.isEmpty || kanaText == word) return word;
    return '$word（$kanaText）';
  }

  factory DebugStudyWordItem.fromMap(Map<String, dynamic> map) {
    return DebugStudyWordItem(
      wordId: map['word_id'] as int,
      word: map['word_text'] as String,
      kana: map['kana_text'] as String?,
      userState: map['user_state'] as int,
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['next_review_at'] as int) * 1000,
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }
}

class DebugStudyWordsResult {
  final int? userId;
  final List<DebugStudyWordItem> items;

  const DebugStudyWordsResult({
    required this.userId,
    required this.items,
  });
}

/// study_words 查询（只读）
class DebugStudyWordsQuery {
  DebugStudyWordsQuery(this._db, this._activeUserQuery);

  final Database _db;
  final ActiveUserQuery _activeUserQuery;

  Future<DebugStudyWordsResult> getStudyWordsForActiveUser() async {
    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return const DebugStudyWordsResult(userId: null, items: []);
    }

    try {
      final results = await _db.rawQuery(
        '''
        SELECT
          sw.word_id,
          w.word AS word_text,
          w.furigana AS kana_text,
          sw.user_state,
          sw.next_review_at,
          sw.created_at,
          sw.updated_at
        FROM study_words sw
        JOIN words w ON w.id = sw.word_id
        WHERE sw.user_id = ?
        ORDER BY sw.updated_at DESC
        ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return DebugStudyWordsResult(
        userId: userId,
        items: results.map(DebugStudyWordItem.fromMap).toList(),
      );
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
}
