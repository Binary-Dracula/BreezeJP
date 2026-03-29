/// 文章摘要模型（用于列表页）
/// 字段名与 Supabase articles 表一致
class ArticleSummary {
  final String id;
  final String title;
  final String cleanTitle;
  final String publishedAt;
  final String audioUrl;
  final int durationMs;
  final int sentenceCount;
  final bool isArchived;

  const ArticleSummary({
    required this.id,
    required this.title,
    required this.cleanTitle,
    required this.publishedAt,
    required this.audioUrl,
    required this.durationMs,
    required this.sentenceCount,
    required this.isArchived,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      cleanTitle: json['clean_title'] as String,
      publishedAt: json['published_at'] as String,
      audioUrl: json['audio_url'] as String,
      durationMs: json['duration_ms'] as int,
      sentenceCount: json['sentence_count'] as int,
      isArchived: (json['is_archived'] as bool?) ?? false,
    );
  }

  factory ArticleSummary.fromMap(Map<String, dynamic> map) {
    return ArticleSummary(
      id: map['id'] as String,
      title: map['title'] as String,
      cleanTitle: map['clean_title'] as String,
      publishedAt: map['published_at'] as String,
      audioUrl: map['audio_url'] as String,
      durationMs: map['duration_ms'] as int,
      sentenceCount: map['sentence_count'] as int,
      isArchived: (map['is_archived'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'clean_title': cleanTitle,
      'published_at': publishedAt,
      'audio_url': audioUrl,
      'duration_ms': durationMs,
      'sentence_count': sentenceCount,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleSummary &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ArticleSummary{id: $id, title: $title, publishedAt: $publishedAt}';
}
