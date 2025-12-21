import '../kana_log.dart';

class KanaLogItem {
  final KanaLog log;

  const KanaLogItem({required this.log});

  factory KanaLogItem.fromLog(KanaLog log) {
    return KanaLogItem(log: log);
  }
}

class KanaLogStats {
  final int total;
  final int firstLearnCount;
  final int reviewCount;
  final int masteredCount;
  final int quizCount;
  final int forgotCount;

  const KanaLogStats({
    required this.total,
    required this.firstLearnCount,
    required this.reviewCount,
    required this.masteredCount,
    required this.quizCount,
    required this.forgotCount,
  });
}
