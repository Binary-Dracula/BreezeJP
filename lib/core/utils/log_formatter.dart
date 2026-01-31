import '../../data/models/study_word.dart';
import '../algorithm/srs_types.dart';

/// 日志格式化工具类
/// 提供统一的日志格式化方法，确保日志输出一致性
class LogFormatter {
  LogFormatter._();

  /// 格式化 StudyWord 为单行摘要
  /// 输出格式: id=1, wordId=123, state=learning, interval=2.50, nextReview=2024-11-30T10:30:00+08:00
  static String formatStudyWord(StudyWord word) {
    final parts = <String>[
      'id=${word.id}',
      'wordId=${word.wordId}',
      'state=${word.userState.name}',
      'interval=${word.interval != null ? '${word.interval}' : '-'}',
      'nextReview=${word.nextReviewAt != null ? formatTimestamp(word.nextReviewAt!) : "null"}',
    ];
    return parts.join(', ');
  }

  /// 格式化 SRS 输入参数
  /// 数值精度: interval 2位小数, easeFactor/stability/difficulty 3位小数
  static String formatSRSInput(SRSInput input) {
    final parts = <String>[
      'interval=${input.interval.toStringAsFixed(2)}',
      'ef=${input.easeFactor.toStringAsFixed(3)}',
      'stability=${input.stability.toStringAsFixed(3)}',
      'difficulty=${input.difficulty.toStringAsFixed(3)}',
      'rating=${input.rating.name}',
    ];
    return parts.join(', ');
  }

  /// 格式化 SRS 输出参数
  /// 数值精度: interval 2位小数, easeFactor/stability/difficulty 3位小数
  static String formatSRSOutput(SRSOutput output) {
    final parts = <String>[
      'interval=${output.interval.toStringAsFixed(2)}',
      'ef=${output.easeFactor.toStringAsFixed(3)}',
      'stability=${output.stability.toStringAsFixed(3)}',
      'difficulty=${output.difficulty.toStringAsFixed(3)}',
      'nextReview=${formatTimestamp(output.nextReviewAt)}',
    ];
    return parts.join(', ');
  }

  /// 格式化时间戳为 ISO 8601 格式（带本地时区）
  /// 输出格式: 2024-11-27T10:30:00+08:00
  static String formatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');

    return '$year-$month-${day}T$hour:$minute:$second$sign$hours:$minutes';
  }

  /// 格式化时长为人类可读格式
  /// 输入: 毫秒
  /// 输出: "2m 30s", "1h 5m", "500ms"
  static String formatDuration(int milliseconds) {
    if (milliseconds < 1000) {
      return '${milliseconds}ms';
    }

    final seconds = milliseconds ~/ 1000;
    if (seconds < 60) {
      final ms = milliseconds % 1000;
      if (ms > 0) {
        return '${seconds}s ${ms}ms';
      }
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      if (remainingSeconds > 0) {
        return '${minutes}m ${remainingSeconds}s';
      }
      return '${minutes}m';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${hours}h';
  }

  /// 格式化键值对为一致的格式
  /// 输出格式: key1=value1, key2=value2
  static String formatKeyValues(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    return data.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  /// 格式化变更集
  /// 输出格式: changes=[key1: before -> after, key2: before -> after]
  static String formatChanges(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    if (after.isEmpty) return 'changes=[]';
    final changes = <String>[];
    for (final entry in after.entries) {
      final key = entry.key;
      final beforeVal = before[key];
      final afterVal = entry.value;
      if (beforeVal != afterVal) {
        changes.add('$key: $beforeVal -> $afterVal');
      }
    }
    if (changes.isEmpty) return 'changes=[]';
    return 'changes=[${changes.join(', ')}]';
  }

  /// 格式化列表摘要
  /// 输出格式: count=5, items=[item1, item2, item3, ...]
  static String formatListSummary<T>(
    List<T> list, {
    int maxItems = 3,
    String Function(T)? itemFormatter,
  }) {
    final count = list.length;
    if (count == 0) {
      return 'count=0, items=[]';
    }

    final formatter = itemFormatter ?? (item) => item.toString();
    final displayItems = list.take(maxItems).map(formatter).toList();
    final itemsStr = displayItems.join(', ');

    if (count > maxItems) {
      return 'count=$count, items=[$itemsStr, ...]';
    }
    return 'count=$count, items=[$itemsStr]';
  }
}
