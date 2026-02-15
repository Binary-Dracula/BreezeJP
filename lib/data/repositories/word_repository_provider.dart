import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'word_repository.dart';

/// WordRepository Provider
/// 提供全局单例的单词数据仓库
final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return WordRepository(() => AppDatabase.instance.database);
});
