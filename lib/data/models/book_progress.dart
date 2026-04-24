/// 辞书学习进度聚合（每用户每本书一条记录）
class BookProgress {
  final int id;
  final int userId;
  final String bookId;
  final int totalWords;
  final int learnedCount;
  final int masteredCount;
  final int ignoredCount;
  final bool isCompleted;

  /// 下次拉取新词从此 sort_order 之后开始
  final int currentSortCursor;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookProgress({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.totalWords,
    required this.learnedCount,
    required this.masteredCount,
    required this.ignoredCount,
    required this.isCompleted,
    required this.currentSortCursor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookProgress.fromMap(Map<String, dynamic> map) {
    return BookProgress(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      bookId: map['book_id'] as String,
      totalWords: map['total_words'] as int,
      learnedCount: map['learned_count'] as int,
      masteredCount: map['mastered_count'] as int,
      ignoredCount: map['ignored_count'] as int,
      isCompleted: (map['is_completed'] as int) == 1,
      currentSortCursor: map['current_sort_cursor'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'user_id': userId,
      'book_id': bookId,
      'total_words': totalWords,
      'learned_count': learnedCount,
      'mastered_count': masteredCount,
      'ignored_count': ignoredCount,
      'is_completed': isCompleted ? 1 : 0,
      'current_sort_cursor': currentSortCursor,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toMapForInsert();
    map['id'] = id;
    return map;
  }

  BookProgress copyWith({
    int? id,
    int? userId,
    String? bookId,
    int? totalWords,
    int? learnedCount,
    int? masteredCount,
    int? ignoredCount,
    bool? isCompleted,
    int? currentSortCursor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      totalWords: totalWords ?? this.totalWords,
      learnedCount: learnedCount ?? this.learnedCount,
      masteredCount: masteredCount ?? this.masteredCount,
      ignoredCount: ignoredCount ?? this.ignoredCount,
      isCompleted: isCompleted ?? this.isCompleted,
      currentSortCursor: currentSortCursor ?? this.currentSortCursor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 已学+已忽略+已掌握 之和
  int get touchedCount => learnedCount + masteredCount + ignoredCount;
}
