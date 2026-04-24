/// 词汇书模型（对齐 Supabase books 表）
class VocabBook {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? coverImageKey;
  final bool isAvailable;
  final bool hasLessons;
  final int wordCount;
  final int? sortOrder;
  final DateTime? updatedAt;

  const VocabBook({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.coverImageKey,
    this.isAvailable = true,
    this.hasLessons = true,
    this.wordCount = 0,
    this.sortOrder,
    this.updatedAt,
  });

  factory VocabBook.fromJson(Map<String, dynamic> json) {
    return VocabBook(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      coverImageKey: json['cover_image_key'] as String?,
      isAvailable: (json['is_available'] as bool?) ?? true,
      hasLessons: json['has_lessons'] == true,
      wordCount: (json['word_count'] as int?) ?? 0,
      sortOrder: json['sort_order'] as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  factory VocabBook.fromMap(Map<String, dynamic> map) {
    return VocabBook(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String?,
      description: map['description'] as String?,
      coverImageKey: map['cover_image_key'] as String?,
      isAvailable: (map['is_available'] as int? ?? 1) == 1,
      hasLessons: (map['has_lessons'] as int? ?? 0) == 1,
      wordCount: map['word_count'] as int? ?? 0,
      sortOrder: map['sort_order'] as int?,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['updated_at'] as int) * 1000,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'cover_image_key': coverImageKey,
      'is_available': isAvailable ? 1 : 0,
      'has_lessons': hasLessons ? 1 : 0,
      'word_count': wordCount,
      'sort_order': sortOrder ?? 0,
      'updated_at': updatedAt != null
          ? updatedAt!.millisecondsSinceEpoch ~/ 1000
          : (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    };
  }
}
