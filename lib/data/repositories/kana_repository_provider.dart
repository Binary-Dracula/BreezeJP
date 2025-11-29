import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kana_repository.dart';

/// KanaRepository Provider
/// 提供全局单例的五十音数据仓库
final kanaRepositoryProvider = Provider<KanaRepository>((ref) {
  return KanaRepository();
});
