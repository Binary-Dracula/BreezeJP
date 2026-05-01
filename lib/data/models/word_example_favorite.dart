class WordExampleFavorite {
  const WordExampleFavorite({
    required this.id,
    required this.userId,
    required this.exampleId,
    required this.wordId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final String exampleId;
  final String wordId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WordExampleFavorite.fromMap(Map<String, dynamic> map) {
    return WordExampleFavorite(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      exampleId: map['example_id'] as String,
      wordId: map['word_id'] as String,
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
      'example_id': exampleId,
      'word_id': wordId,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toMapForInsert();
    map['id'] = id;
    return map;
  }

  WordExampleFavorite copyWith({
    int? id,
    int? userId,
    String? exampleId,
    String? wordId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WordExampleFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exampleId: exampleId ?? this.exampleId,
      wordId: wordId ?? this.wordId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
