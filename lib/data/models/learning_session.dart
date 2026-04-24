import 'dart:convert';

/// 学习批次会话（记录用户某次学习的断点状态）
class LearningSession {
  final int id;
  final int userId;
  final String bookId;
  final List<String> wordIds;
  final int currentIndex;
  final int batchStartSort;
  final int batchEndSort;
  final DateTime startedAt;

  /// 'active' | 'completed'
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.wordIds,
    required this.currentIndex,
    required this.batchStartSort,
    required this.batchEndSort,
    required this.startedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LearningSession.fromMap(Map<String, dynamic> map) {
    return LearningSession(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      bookId: map['book_id'] as String,
      wordIds: List<String>.from(jsonDecode(map['word_ids'] as String) as List),
      currentIndex: map['current_index'] as int,
      batchStartSort: map['batch_start_sort'] as int,
      batchEndSort: map['batch_end_sort'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['started_at'] as int) * 1000,
      ),
      status: map['status'] as String,
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
      'word_ids': jsonEncode(wordIds),
      'current_index': currentIndex,
      'batch_start_sort': batchStartSort,
      'batch_end_sort': batchEndSort,
      'started_at': startedAt.millisecondsSinceEpoch ~/ 1000,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toMapForInsert();
    map['id'] = id;
    return map;
  }

  LearningSession copyWith({
    int? id,
    int? userId,
    String? bookId,
    List<String>? wordIds,
    int? currentIndex,
    int? batchStartSort,
    int? batchEndSort,
    DateTime? startedAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      wordIds: wordIds ?? this.wordIds,
      currentIndex: currentIndex ?? this.currentIndex,
      batchStartSort: batchStartSort ?? this.batchStartSort,
      batchEndSort: batchEndSort ?? this.batchEndSort,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}
