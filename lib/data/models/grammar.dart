class Grammar {
  final int id;
  final String title;
  final String? jlptLevel;
  final int usageFrequency;
  final DateTime createdAt;
  final DateTime updatedAt;

  Grammar({
    required this.id,
    required this.title,
    this.jlptLevel,
    this.usageFrequency = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Grammar.fromMap(Map<String, dynamic> map) {
    return Grammar(
      id: map['id'] as int,
      title: map['title'] as String,
      jlptLevel: map['jlpt_level'] as String?,
      usageFrequency: map['usage_frequency'] as int? ?? 0,
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
      'usage_frequency': usageFrequency,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
      'updated_at': (updatedAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  Grammar copyWith({
    int? id,
    String? title,
    String? jlptLevel,
    int? usageFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Grammar(
      id: id ?? this.id,
      title: title ?? this.title,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      usageFrequency: usageFrequency ?? this.usageFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
