/// 词汇书模型（对齐 Supabase books 表）
class VocabBook {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? coverImageKey;
  final bool hasLessons;
  final int wordCount;
  final int? sortOrder;

  const VocabBook({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.coverImageKey,
    this.hasLessons = true,
    this.wordCount = 0,
    this.sortOrder,
  });

  factory VocabBook.fromJson(Map<String, dynamic> json) {
    return VocabBook(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      coverImageKey: json['cover_image_key'] as String?,
      hasLessons: json['has_lessons'] == true,
      wordCount: (json['word_count'] as int?) ?? 0,
      sortOrder: json['sort_order'] as int?,
    );
  }
}
