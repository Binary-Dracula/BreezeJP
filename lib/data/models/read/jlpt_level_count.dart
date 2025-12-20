/// JLPT 等级计数（统计 DTO）
class JlptLevelCount {
  final String level;
  final int count;

  const JlptLevelCount({required this.level, required this.count});

  factory JlptLevelCount.fromMap(Map<String, dynamic> map) {
    return JlptLevelCount(
      level: map['jlpt_level'] as String,
      count: map['count'] as int,
    );
  }
}
