import 'package:json_annotation/json_annotation.dart';

part 'article_item.g.dart';

@JsonSerializable(explicitToJson: true)
class ArticleItem {
  final String text;
  final String translation;
  @JsonKey(name: 'start_ms')
  final int startMs;

  @JsonKey(name: 'end_ms')
  final int endMs;
  final int index;

  ArticleItem({
    required this.text,
    required this.translation,
    required this.startMs,
    required this.endMs,
    required this.index,
  });

  factory ArticleItem.fromJson(Map<String, dynamic> json) =>
      _$ArticleItemFromJson(json);

  Map<String, dynamic> toJson() => _$ArticleItemToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          translation == other.translation &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          index == other.index;

  @override
  int get hashCode =>
      text.hashCode ^
      translation.hashCode ^
      startMs.hashCode ^
      endMs.hashCode ^
      index.hashCode;

  @override
  String toString() {
    return 'ArticleItem{text: $text, translation: $translation, startMs: $startMs, endMs: $endMs, index: $index}';
  }
}
