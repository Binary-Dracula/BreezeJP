class Grammar {
  final int id;
  final String title;
  final String? meaning;
  final String? connection;
  final String? jlptLevel;
  final String? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Grammar({
    required this.id,
    required this.title,
    this.meaning,
    this.connection,
    this.jlptLevel,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Grammar.fromMap(Map<String, dynamic> map) {
    return Grammar(
      id: map['id'] as int,
      title: map['title'] as String,
      meaning: map['meaning'] as String?,
      connection: map['connection'] as String?,
      jlptLevel: map['jlpt_level'] as String?,
      tags: map['tags'] as String?,
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
      'meaning': meaning,
      'connection': connection,
      'jlpt_level': jlptLevel,
      'tags': tags,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
      'updated_at': (updatedAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  // To support copying objects with modified fields if needed
  Grammar copyWith({
    int? id,
    String? title,
    String? meaning,
    String? connection,
    String? jlptLevel,
    String? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Grammar(
      id: id ?? this.id,
      title: title ?? this.title,
      meaning: meaning ?? this.meaning,
      connection: connection ?? this.connection,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
