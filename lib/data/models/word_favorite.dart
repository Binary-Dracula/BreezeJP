class WordFavorite {
  const WordFavorite({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.bookId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final String wordId;
  final String bookId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WordFavorite.fromMap(Map<String, dynamic> map) {
    return WordFavorite(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      wordId: map['word_id'] as String,
      bookId: map['book_id'] as String,
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
      'word_id': wordId,
      'book_id': bookId,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toMapForInsert();
    map['id'] = id;
    return map;
  }

  WordFavorite copyWith({
    int? id,
    int? userId,
    String? wordId,
    String? bookId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WordFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordId: wordId ?? this.wordId,
      bookId: bookId ?? this.bookId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
