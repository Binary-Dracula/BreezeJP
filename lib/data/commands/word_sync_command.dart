import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/app_logger.dart';
import '../models/word_detail.dart';

/// 单词增量同步命令
///
/// 向 API 请求 since 时间戳之后更新的单词，
/// 只覆盖本地已存在的单词（跳过本地没有的）。
class WordSyncCommand {
  WordSyncCommand(this._db);

  final Database _db;
  final _dio = DioClient.instance.dio;

  static const _lastSyncKey = 'words_last_sync_time';

  /// 增量同步已有单词的最新内容
  ///
  /// 返回本次实际更新的单词数量。
  Future<int> syncUpdatedWords() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);

    // 首次运行（没有时间戳）跳过，避免拉取全量数据
    if (lastSync == null) {
      final serverTime = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_lastSyncKey, serverTime);
      logger.info('[WordSync] 首次运行，初始化时间戳: $serverTime');
      return 0;
    }

    logger.info('[WordSync] 开始同步，since=$lastSync');

    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.wordSync,
      queryParameters: {'since': lastSync},
    );

    final body = response.data!;
    final data = body['data'] as List<dynamic>;
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    final serverTime =
        meta['server_time'] as String? ??
        DateTime.now().toUtc().toIso8601String();

    if (data.isEmpty) {
      await prefs.setString(_lastSyncKey, serverTime);
      logger.info('[WordSync] 无更新，更新时间戳: $serverTime');
      return 0;
    }

    final details = data
        .map((e) => WordDetail.fromJson(e as Map<String, dynamic>))
        .toList();

    int updated = 0;

    await _db.transaction((txn) async {
      for (final detail in details) {
        final word = detail.word;

        // 仅更新本地已存在的单词，跳过用户尚未下载的
        final existing = await txn.query(
          'words',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [word.id],
          limit: 1,
        );
        if (existing.isEmpty) continue;

        await txn.insert(
          'words',
          word.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert('word_details', {
          'word_id': word.id,
          'rich_content': detail.richContent.toJsonString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await txn.delete(
          'word_examples',
          where: 'word_id = ?',
          whereArgs: [word.id],
        );
        for (final example in detail.examples) {
          await txn.insert('word_examples', example.toMap());
        }

        updated++;
      }
    });

    // 同步完成后更新时间戳，下次使用新时间戳
    await prefs.setString(_lastSyncKey, serverTime);

    logger.info('[WordSync] 同步完成，更新 $updated 条，server_time=$serverTime');
    return updated;
  }
}
