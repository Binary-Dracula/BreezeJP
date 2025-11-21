import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'study_word_repository.dart';

/// StudyWordRepository Provider
/// 提供全局单例的学习进度数据仓库
final studyWordRepositoryProvider = Provider<StudyWordRepository>((ref) {
  return StudyWordRepository();
});
