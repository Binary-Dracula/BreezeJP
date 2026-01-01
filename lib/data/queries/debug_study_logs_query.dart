import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/study_log.dart';
import 'active_user_query.dart';
import 'active_user_query_provider.dart';

final debugStudyLogsQueryProvider = Provider<DebugStudyLogsQuery>((ref) {
  final db = ref.read(databaseProvider);
  final activeUserQuery = ref.read(activeUserQueryProvider);
  return DebugStudyLogsQuery(db, activeUserQuery);
});

class DebugStudyLogItem {
  final int id;
  final int wordId;
  final String word;
  final String? kana;
  final int logType;
  final DateTime createdAt;

  const DebugStudyLogItem({
    required this.id,
    required this.wordId,
    required this.word,
    required this.kana,
    required this.logType,
    required this.createdAt,
  });

  bool get isToday {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return !createdAt.isBefore(startOfToday);
  }

  String get logTypeLabel => LogType.fromValue(logType).name;

  String get displayWord {
    final kanaText = kana ?? '';
    if (kanaText.isEmpty || kanaText == word) return word;
    return '$word（$kanaText）';
  }

  factory DebugStudyLogItem.fromMap(Map<String, dynamic> map) {
    return DebugStudyLogItem(
      id: map['id'] as int,
      wordId: map['word_id'] as int,
      word: map['word_text'] as String,
      kana: map['kana_text'] as String?,
      logType: map['log_type'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }
}

class DebugStudyLogsResult {
  final int? userId;
  final List<DebugStudyLogItem> items;

  const DebugStudyLogsResult({
    required this.userId,
    required this.items,
  });
}

/// study_logs 查询（只读）
class DebugStudyLogsQuery {
  DebugStudyLogsQuery(this._db, this._activeUserQuery);

  final Database _db;
  final ActiveUserQuery _activeUserQuery;

  Future<DebugStudyLogsResult> getStudyLogsForActiveUser() async {
    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return const DebugStudyLogsResult(userId: null, items: []);
    }

    try {
      final results = await _db.rawQuery(
        '''
        SELECT
          sl.id,
          sl.word_id,
          w.word AS word_text,
          w.furigana AS kana_text,
          sl.log_type,
          sl.created_at
        FROM study_logs sl
        JOIN words w ON w.id = sl.word_id
        WHERE sl.user_id = ?
        ORDER BY sl.created_at ASC
        ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return DebugStudyLogsResult(
        userId: userId,
        items: results.map(DebugStudyLogItem.fromMap).toList(),
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
