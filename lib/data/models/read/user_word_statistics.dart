/// 用户单词学习统计（DTO）
class UserWordStatistics {
  final int totalWords;
  final int newWords;
  final int learningWords;
  final int masteredWords;
  final int ignoredWords;
  final int totalReviews;
  final double avgEaseFactor;
  final int totalFails;

  const UserWordStatistics({
    required this.totalWords,
    required this.newWords,
    required this.learningWords,
    required this.masteredWords,
    required this.ignoredWords,
    required this.totalReviews,
    required this.avgEaseFactor,
    required this.totalFails,
  });

  factory UserWordStatistics.fromMap(Map<String, dynamic> map) {
    return UserWordStatistics(
      totalWords: (map['total_words'] as int?) ?? 0,
      newWords: (map['new_words'] as int?) ?? 0,
      learningWords: (map['learning_words'] as int?) ?? 0,
      masteredWords: (map['mastered_words'] as int?) ?? 0,
      ignoredWords: (map['ignored_words'] as int?) ?? 0,
      totalReviews: (map['total_reviews'] as int?) ?? 0,
      avgEaseFactor: (map['avg_ease_factor'] as num?)?.toDouble() ?? 0,
      totalFails: (map['total_fails'] as int?) ?? 0,
    );
  }
}
