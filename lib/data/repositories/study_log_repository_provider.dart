import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'study_log_repository.dart';

/// StudyLogRepository Provider
/// 提供全局单例的学习日志数据仓库
final studyLogRepositoryProvider = Provider<StudyLogRepository>((ref) {
  return StudyLogRepository(() => AppDatabase.instance.database);
});
