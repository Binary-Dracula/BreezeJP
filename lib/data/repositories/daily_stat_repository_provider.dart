import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'daily_stat_repository.dart';

/// DailyStatRepository Provider
/// 提供全局单例的每日统计数据仓库
final dailyStatRepositoryProvider = Provider<DailyStatRepository>((ref) {
  return DailyStatRepository();
});
