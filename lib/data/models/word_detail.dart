import 'dart:convert';
import 'word.dart';
import '../../core/constants/learning_status.dart';

/// 单词完整详情（来自远端单词详情 API）
class WordDetail {
  final Word word;
  final WordRichContent richContent;
  final List<WordExample> examples;
  final LearningStatus userState;
  final bool isFavorited;

  WordDetail({
    required this.word,
    required this.richContent,
    required this.examples,
    this.userState = LearningStatus.learning,
    this.isFavorited = false,
  });

  /// 获取主要释义
  String? get primaryMeaning =>
      word.primaryMeaning ?? richContent.primaryMeaning;

  /// 获取所有释义文本
  List<String> get allMeanings =>
      richContent.meaningEntries.map((entry) => entry.meaning).toList();

  String? get audioSource => word.audioSource;

  WordDetail copyWith({
    Word? word,
    WordRichContent? richContent,
    List<WordExample>? examples,
    LearningStatus? userState,
    bool? isFavorited,
  }) {
    return WordDetail(
      word: word ?? this.word,
      richContent: richContent ?? this.richContent,
      examples: examples ?? this.examples,
      userState: userState ?? this.userState,
      isFavorited: isFavorited ?? this.isFavorited,
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
      isFavorited: json['is_favorited'] == true,
    );
  }
}

/// 远端 detail payload 中 rich_content 的结构化包装
class WordRichContent {
  final List<Map<String, dynamic>> meanings;
  final List<Map<String, dynamic>>? grammarRules;
  final Map<String, dynamic>? conjugations;
  final Map<String, dynamic>? synonymsAntonyms;
  final List<Map<String, dynamic>>? collocations;
  final List<Map<String, dynamic>>? commonMistakes;

  WordRichContent({
    required this.meanings,
    this.grammarRules,
    this.conjugations,
    this.synonymsAntonyms,
    this.collocations,
    this.commonMistakes,
  });

  factory WordRichContent.empty() => WordRichContent(meanings: []);

  String? get primaryMeaning {
    final entries = meaningEntries;
    if (entries.isEmpty) return null;
    return entries.first.meaning;
  }

  List<WordMeaningEntry> get meaningEntries => meanings
      .map(WordMeaningEntry.fromMap)
      .where((entry) => entry.meaning.isNotEmpty)
      .toList();

  List<WordGrammarRuleEntry> get grammarRuleEntries =>
      (grammarRules ?? const [])
          .map(WordGrammarRuleEntry.fromMap)
          .where(
            (entry) => entry.pattern.isNotEmpty || entry.explanation.isNotEmpty,
          )
          .toList();

  List<WordCollocationEntry> get collocationEntries =>
      (collocations ?? const [])
          .map(WordCollocationEntry.fromMap)
          .where((entry) => entry.phrase.isNotEmpty || entry.meaning.isNotEmpty)
          .toList();

  List<WordCommonMistakeEntry> get commonMistakeEntries =>
      (commonMistakes ?? const [])
          .map(WordCommonMistakeEntry.fromMap)
          .where((entry) => entry.explanation.isNotEmpty)
          .toList();

  List<WordRelationEntry> get synonymEntries =>
      _relationEntriesForKey('synonyms');

  List<WordRelationEntry> get antonymEntries =>
      _relationEntriesForKey('antonyms');

  List<WordConjugationEntry> get conjugationEntries {
    final raw = conjugations;
    if (raw == null || raw.isEmpty) return const [];

    const preferredOrder = [
      'dictionary_form',
      'masu_form',
      'te_form',
      'ta_form',
      'nai_form',
      'potential_form',
      'passive_form',
      'causative_form',
    ];

    final ordered = <WordConjugationEntry>[];
    for (final key in preferredOrder) {
      final value = _normalizedString(raw[key]);
      if (value != null) {
        ordered.add(WordConjugationEntry(key: key, value: value));
      }
    }

    for (final entry in raw.entries) {
      if (preferredOrder.contains(entry.key)) continue;
      final value = _normalizedString(entry.value);
      if (value == null) continue;
      ordered.add(WordConjugationEntry(key: entry.key, value: value));
    }

    return ordered;
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
      conjugations: _toNullableMap(content['conjugations']),
      synonymsAntonyms: _toNullableMap(content['synonyms_antonyms']),
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
      if (synonymsAntonyms != null) 'synonyms_antonyms': synonymsAntonyms,
      if (collocations != null) 'collocations': collocations,
      if (commonMistakes != null) 'common_mistakes': commonMistakes,
    };
    return jsonEncode(map);
  }

  static List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
    if (value == null) return [];
    return (value as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static List<Map<String, dynamic>>? _toNullableListOfMaps(dynamic value) {
    if (value == null) return null;
    return (value as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Map<String, dynamic>? _toNullableMap(dynamic value) {
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  List<WordRelationEntry> _relationEntriesForKey(String key) {
    final rawList = synonymsAntonyms?[key];
    if (rawList is! List) return const [];
    return rawList
        .map(
          (entry) => WordRelationEntry.fromMap(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .where(
          (entry) =>
              entry.word.isNotEmpty || (entry.meaning?.isNotEmpty ?? false),
        )
        .toList();
  }

  static String? _normalizedString(dynamic value) {
    if (value == null) return null;
    final normalized = value is String ? value.trim() : value.toString().trim();
    if (normalized.isEmpty) return null;

    const placeholderValues = {
      'n/a',
      'na',
      'none',
      'null',
      'nil',
      '无',
      '無',
      '不适用',
      '不適用',
      '无变形',
      '無変形',
      '名词无变形',
      '名詞無変形',
      '副词无变形',
      '副詞無変形',
      '形容词无变形',
      '形容詞無変形',
    };

    return placeholderValues.contains(normalized.toLowerCase())
        ? null
        : normalized;
  }
}

/// 例句模型（对齐 word_examples 表）
class WordExample {
  final String id;
  final String wordId;
  final String japanese;
  final String chinese;
  final bool hasAudio;
  final int sortOrder;
  final bool isFavorited;

  WordExample({
    required this.id,
    required this.wordId,
    required this.japanese,
    required this.chinese,
    this.hasAudio = false,
    this.sortOrder = 0,
    this.isFavorited = false,
  });

  factory WordExample.fromMap(Map<String, dynamic> map) {
    return WordExample(
      id: map['id'] as String,
      wordId: map['word_id'] as String,
      japanese: map['japanese'] as String,
      chinese: (map['chinese'] as String?) ?? '',
      hasAudio: (map['has_audio'] as int?) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isFavorited: false,
    );
  }

  factory WordExample.fromJson(Map<String, dynamic> json) {
    return WordExample(
      id: json['id'] as String,
      wordId: json['word_id'] as String,
      japanese: json['japanese'] as String,
      chinese: (json['chinese'] as String?) ?? '',
      hasAudio: json['has_audio'] == true,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isFavorited: json['is_favorited'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'japanese': japanese,
      'chinese': chinese,
      'has_audio': hasAudio ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}

class WordMeaningEntry {
  final String meaning;
  final String? partOfSpeech;
  final String? note;

  const WordMeaningEntry({required this.meaning, this.partOfSpeech, this.note});

  factory WordMeaningEntry.fromMap(Map<String, dynamic> map) {
    final meaning =
        WordRichContent._normalizedString(map['meaning']) ??
        WordRichContent._normalizedString(map['definition']) ??
        WordRichContent._normalizedString(map['translation']) ??
        '';
    final note =
        WordRichContent._normalizedString(map['notes']) ??
        WordRichContent._normalizedString(map['nuance']) ??
        WordRichContent._normalizedString(map['explanation']);
    final partOfSpeech =
        WordRichContent._normalizedString(map['part_of_speech']) ??
        WordRichContent._normalizedString(map['pos']);

    return WordMeaningEntry(
      meaning: meaning,
      partOfSpeech: partOfSpeech,
      note: note,
    );
  }
}

class WordGrammarRuleEntry {
  final String pattern;
  final String explanation;

  const WordGrammarRuleEntry({
    required this.pattern,
    required this.explanation,
  });

  factory WordGrammarRuleEntry.fromMap(Map<String, dynamic> map) {
    return WordGrammarRuleEntry(
      pattern: WordRichContent._normalizedString(map['pattern']) ?? '',
      explanation:
          WordRichContent._normalizedString(map['explanation']) ??
          WordRichContent._normalizedString(map['meaning']) ??
          '',
    );
  }
}

class WordCollocationEntry {
  final String phrase;
  final String meaning;

  const WordCollocationEntry({required this.phrase, required this.meaning});

  factory WordCollocationEntry.fromMap(Map<String, dynamic> map) {
    return WordCollocationEntry(
      phrase:
          WordRichContent._normalizedString(map['phrase']) ??
          WordRichContent._normalizedString(map['word']) ??
          '',
      meaning: WordRichContent._normalizedString(map['meaning']) ?? '',
    );
  }
}

class WordCommonMistakeEntry {
  final String? mistakeType;
  final String explanation;

  const WordCommonMistakeEntry({this.mistakeType, required this.explanation});

  factory WordCommonMistakeEntry.fromMap(Map<String, dynamic> map) {
    return WordCommonMistakeEntry(
      mistakeType: WordRichContent._normalizedString(map['mistake_type']),
      explanation:
          WordRichContent._normalizedString(map['explanation']) ??
          WordRichContent._normalizedString(map['note']) ??
          '',
    );
  }
}

class WordRelationEntry {
  final String word;
  final String? meaning;
  final String? difference;

  const WordRelationEntry({required this.word, this.meaning, this.difference});

  factory WordRelationEntry.fromMap(Map<String, dynamic> map) {
    return WordRelationEntry(
      word: WordRichContent._normalizedString(map['word']) ?? '',
      meaning: WordRichContent._normalizedString(map['meaning']),
      difference: WordRichContent._normalizedString(map['difference']),
    );
  }
}

class WordConjugationEntry {
  final String key;
  final String value;

  const WordConjugationEntry({required this.key, required this.value});
}
