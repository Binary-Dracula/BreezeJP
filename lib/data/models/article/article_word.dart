import 'package:json_annotation/json_annotation.dart';

part 'article_word.g.dart';

/// 文章中的单个分词单元，由 Kuromoji 分词器生成
@JsonSerializable()
class ArticleWord {
  @JsonKey(name: 'word_id')
  final int? wordId;

  @JsonKey(name: 'word_type')
  final String? wordType;

  @JsonKey(name: 'word_position')
  final int? wordPosition;

  /// 表层形式（原文中出现的词形）
  @JsonKey(name: 'surface_form')
  final String surfaceForm;

  /// 词性（名詞、動詞、助詞 等）
  final String pos;

  /// 词性细分1
  @JsonKey(name: 'pos_detail_1')
  final String posDetail1;

  /// 词性细分2
  @JsonKey(name: 'pos_detail_2')
  final String? posDetail2;

  /// 词性细分3
  @JsonKey(name: 'pos_detail_3')
  final String? posDetail3;

  /// 活用型（如 "一段", "*"）
  @JsonKey(name: 'conjugated_type')
  final String? conjugatedType;

  /// 活用形（如 "基本形", "*"）
  @JsonKey(name: 'conjugated_form')
  final String? conjugatedForm;

  /// 基本形态
  @JsonKey(name: 'basic_form')
  final String basicForm;

  /// 片假名读音
  final String? reading;

  /// 发音
  final String? pronunciation;

  /// 整词平假名读音（纯假名词为空字符串）
  final String furigana;

  /// 带注音的格式，可直接投喂 ruby_text 组件
  /// 例如: "増[ふ]える"、"総理[そうり]"、"これから"
  @JsonKey(name: 'ruby_text')
  final String rubyText;

  ArticleWord({
    this.wordId,
    this.wordType,
    this.wordPosition,
    required this.surfaceForm,
    this.pos = '',
    this.posDetail1 = '',
    this.posDetail2,
    this.posDetail3,
    this.conjugatedType,
    this.conjugatedForm,
    this.basicForm = '',
    this.reading,
    this.pronunciation,
    this.furigana = '',
    required this.rubyText,
  });

  factory ArticleWord.fromJson(Map<String, dynamic> json) =>
      _$ArticleWordFromJson(json);

  Map<String, dynamic> toJson() => _$ArticleWordToJson(this);

  /// 是否为标点符号
  bool get isPunctuation => pos == '記号' || pos == '補助記号';

  /// 是否包含汉字（有假名注音）
  bool get hasKanji => furigana.isNotEmpty;

  @override
  String toString() =>
      'ArticleWord{surfaceForm: $surfaceForm, rubyText: $rubyText, pos: $pos}';
}
