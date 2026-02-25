import 'package:json_annotation/json_annotation.dart';

import 'article_item.dart';

part 'article.g.dart';

@JsonSerializable(explicitToJson: true)
class Article {
  final String id;
  final String title;

  /// The local path to the audio file if available. e.g "output/ne2026/ne2026.mp3"
  @JsonKey(name: 'local_audio_path')
  final String? localAudioPath;

  /// The original URL to the remote audio file
  @JsonKey(name: 'audio_uri')
  final String? audioUri;

  @JsonKey(name: 'audio_size')
  final int audioSize;

  @JsonKey(name: 'duration_ms')
  final int durationMs;

  @JsonKey(name: 'has_sync_data')
  final bool hasSyncData;

  /// List of split sentences that make up the article content
  final List<ArticleItem> items;

  Article({
    required this.id,
    required this.title,
    this.localAudioPath,
    this.audioUri,
    this.audioSize = 0,
    this.durationMs = 0,
    this.hasSyncData = false,
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
          audioSize == other.audioSize &&
          durationMs == other.durationMs &&
          hasSyncData == other.hasSyncData &&
          _listEquals(items, other.items);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      localAudioPath.hashCode ^
      audioUri.hashCode ^
      audioSize.hashCode ^
      durationMs.hashCode ^
      hasSyncData.hashCode ^
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
    return 'Article{id: $id, title: $title, localAudioPath: $localAudioPath, audioUri: $audioUri, audioSize: $audioSize, durationMs: $durationMs, hasSyncData: $hasSyncData, items: $items}';
  }
}
