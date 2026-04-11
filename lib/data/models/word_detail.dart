import 'dart:convert';
import 'word.dart';
import '../../core/constants/learning_status.dart';

/// 单词完整详情（2.0 — 聚合 words + word_details + word_examples）
class WordDetail {
  final Word word;
  final WordRichContent richContent;
  final List<WordExample> examples;
  final LearningStatus userState;

  WordDetail({
    required this.word,
    required this.richContent,
    required this.examples,
    this.userState = LearningStatus.seen,
  });

  /// 获取主要释义
  String? get primaryMeaning =>
      word.primaryMeaning ?? richContent.primaryMeaning;

  /// 获取所有释义文本
  List<String> get allMeanings =>
      richContent.meanings.map((m) => m['meaning'] as String? ?? '').toList();

  WordDetail copyWith({
    Word? word,
    WordRichContent? richContent,
    List<WordExample>? examples,
    LearningStatus? userState,
  }) {
    return WordDetail(
      word: word ?? this.word,
      richContent: richContent ?? this.richContent,
      examples: examples ?? this.examples,
      userState: userState ?? this.userState,
    );
  }

  /// 从本地 DB 的三表 JOIN 创建
  factory WordDetail.fromDbMaps({
    required Map<String, dynamic> wordMap,
    Map<String, dynamic>? detailMap,
    List<Map<String, dynamic>>? exampleMaps,
    int? userState,
  }) {
    return WordDetail(
      word: Word.fromMap(wordMap),
      richContent: detailMap != null
          ? WordRichContent.fromMap(detailMap)
          : WordRichContent.empty(),
      examples: exampleMaps?.map((m) => WordExample.fromMap(m)).toList() ?? [],
      userState: userState != null
          ? LearningStatus.fromValue(userState)
          : LearningStatus.seen,
    );
  }

  /// 从 Supabase API 的 VocabFullDetail JSON 创建
  factory WordDetail.fromJson(Map<String, dynamic> json) {
    return WordDetail(
      word: Word.fromJson(json),
      richContent: json['rich_content'] != null
          ? WordRichContent.fromJson(
              json['rich_content'] as Map<String, dynamic>,
            )
          : WordRichContent.empty(),
      examples:
          (json['examples'] as List<dynamic>?)
              ?.map((e) => WordExample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// word_details.rich_content 的结构化包装
class WordRichContent {
  final List<Map<String, dynamic>> meanings;
  final List<Map<String, dynamic>>? grammarRules;
  final Map<String, dynamic>? conjugations;
  final List<Map<String, dynamic>>? kanjiComponents;
  final Map<String, dynamic>? synonymsAntonyms;
  final List<Map<String, dynamic>>? collocations;
  final List<Map<String, dynamic>>? commonMistakes;

  WordRichContent({
    required this.meanings,
    this.grammarRules,
    this.conjugations,
    this.kanjiComponents,
    this.synonymsAntonyms,
    this.collocations,
    this.commonMistakes,
  });

  factory WordRichContent.empty() => WordRichContent(meanings: []);

  String? get primaryMeaning {
    if (meanings.isEmpty) return null;
    return meanings.first['meaning'] as String?;
  }

  /// 从本地 DB 的 rich_content TEXT 字段解析
  factory WordRichContent.fromMap(Map<String, dynamic> map) {
    final raw = map['rich_content'];
    if (raw == null) return WordRichContent.empty();
    final Map<String, dynamic> content = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : raw as Map<String, dynamic>;
    return WordRichContent._fromParsed(content);
  }

  /// 从 API JSON 创建
  factory WordRichContent.fromJson(Map<String, dynamic> json) {
    return WordRichContent._fromParsed(json);
  }

  factory WordRichContent._fromParsed(Map<String, dynamic> content) {
    return WordRichContent(
      meanings: _toListOfMaps(content['meanings']),
      grammarRules: _toNullableListOfMaps(content['grammar_rules']),
      conjugations: content['conjugations'] as Map<String, dynamic>?,
      kanjiComponents: _toNullableListOfMaps(content['kanji_components']),
      synonymsAntonyms: content['synonyms_antonyms'] as Map<String, dynamic>?,
      collocations: _toNullableListOfMaps(content['collocations']),
      commonMistakes: _toNullableListOfMaps(content['common_mistakes']),
    );
  }

  /// 序列化为 JSON 字符串（写回 DB）
  String toJsonString() {
    final map = <String, dynamic>{
      'meanings': meanings,
      if (grammarRules != null) 'grammar_rules': grammarRules,
      if (conjugations != null) 'conjugations': conjugations,
      if (kanjiComponents != null) 'kanji_components': kanjiComponents,
      if (synonymsAntonyms != null) 'synonyms_antonyms': synonymsAntonyms,
      if (collocations != null) 'collocations': collocations,
      if (commonMistakes != null) 'common_mistakes': commonMistakes,
    };
    return jsonEncode(map);
  }

  static List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
    if (value == null) return [];
    return (value as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static List<Map<String, dynamic>>? _toNullableListOfMaps(dynamic value) {
    if (value == null) return null;
    return (value as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

/// 例句模型（对齐 word_examples 表）
class WordExample {
  final String id;
  final String wordId;
  final String level;
  final String japanese;
  final String chinese;
  final bool hasAudio;
  final int sortOrder;

  WordExample({
    required this.id,
    required this.wordId,
    required this.level,
    required this.japanese,
    required this.chinese,
    this.hasAudio = false,
    this.sortOrder = 0,
  });

  factory WordExample.fromMap(Map<String, dynamic> map) {
    return WordExample(
      id: map['id'] as String,
      wordId: map['word_id'] as String,
      level: (map['level'] as String?) ?? 'Casual',
      japanese: map['japanese'] as String,
      chinese: (map['chinese'] as String?) ?? '',
      hasAudio: (map['has_audio'] as int?) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  factory WordExample.fromJson(Map<String, dynamic> json) {
    return WordExample(
      id: json['id'] as String,
      wordId: json['word_id'] as String,
      level: (json['level'] as String?) ?? 'Casual',
      japanese: json['japanese'] as String,
      chinese: (json['chinese'] as String?) ?? '',
      hasAudio: json['has_audio'] == true,
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'level': level,
      'japanese': japanese,
      'chinese': chinese,
      'has_audio': hasAudio ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}
