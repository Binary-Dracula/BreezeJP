class Grammar {
  final int id;
  final String title;
  final String? jlptLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Grammar({
    required this.id,
    required this.title,
    this.jlptLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Grammar.fromMap(Map<String, dynamic> map) {
    return Grammar(
      id: map['id'] as int,
      title: map['title'] as String,
      jlptLevel: map['jlpt_level'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'jlpt_level': jlptLevel,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
      'updated_at': (updatedAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  Grammar copyWith({
    int? id,
    String? title,
    String? jlptLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Grammar(
      id: id ?? this.id,
      title: title ?? this.title,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
