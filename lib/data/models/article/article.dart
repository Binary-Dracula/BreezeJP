import 'package:json_annotation/json_annotation.dart';

import 'article_item.dart';

part 'article.g.dart';

@JsonSerializable(explicitToJson: true)
class Article {
  final String id;
  final String title;

  @JsonKey(name: 'clean_title')
  final String cleanTitle;

  /// The local path to the audio file if available. e.g "output/ne2026/ne2026.mp3"
  @JsonKey(name: 'local_audio_path')
  final String? localAudioPath;

  /// The original URL to the remote audio file
  @JsonKey(name: 'audio_uri')
  final String? audioUri;

  @JsonKey(name: 'duration_ms')
  final int durationMs;

  /// List of split sentences that make up the article content
  final List<ArticleItem> items;

  Article({
    required this.id,
    required this.title,
    required this.cleanTitle,
    this.localAudioPath,
    this.audioUri,
    this.durationMs = 0,
    required this.items,
  });

  factory Article.fromJson(Map<String, dynamic> json) =>
      _$ArticleFromJson(json);

  Map<String, dynamic> toJson() => _$ArticleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          localAudioPath == other.localAudioPath &&
          audioUri == other.audioUri &&
          durationMs == other.durationMs &&
          _listEquals(items, other.items);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      localAudioPath.hashCode ^
      audioUri.hashCode ^
      durationMs.hashCode ^
      Object.hashAll(items);

  bool _listEquals(List<ArticleItem> a, List<ArticleItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'Article{id: $id, title: $title, localAudioPath: $localAudioPath, audioUri: $audioUri, durationMs: $durationMs, items: $items}';
  }
}
