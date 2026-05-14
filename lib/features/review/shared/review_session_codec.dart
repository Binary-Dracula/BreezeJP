import 'dart:convert';

import '../../../data/models/kana_learning_state.dart';
import '../../../data/models/kana_letter.dart';
import '../../../data/models/study_word.dart';
import '../../../data/models/word_detail.dart';
import '../../kana/review/state/kana_review_state.dart';
import '../../kana/review/state/review_kana_item.dart';
import '../../word_review/state/word_review_item.dart';
import '../../word_review/state/word_review_state.dart';

class DecodedWordReviewSessionPayload {
  const DecodedWordReviewSessionPayload({
    required this.initialItems,
    required this.dynamicQueue,
    required this.answeredResults,
    required this.currentIndex,
  });

  final List<WordReviewItem> initialItems;
  final List<WordReviewItem> dynamicQueue;
  final List<WordReviewAnsweredResult> answeredResults;
  final int currentIndex;
}

class DecodedKanaReviewSessionPayload {
  const DecodedKanaReviewSessionPayload({
    required this.initialItems,
    required this.dynamicQueue,
    required this.answeredResults,
    required this.currentIndex,
  });

  final List<ReviewKanaItem> initialItems;
  final List<ReviewKanaItem> dynamicQueue;
  final List<KanaReviewAnsweredResult> answeredResults;
  final int currentIndex;
}

String encodeWordReviewSessionPayload({
  required List<WordReviewItem> initialItems,
  required List<WordReviewItem> dynamicQueue,
  required List<WordReviewAnsweredResult> answeredResults,
  required int currentIndex,
}) {
  return jsonEncode({
    'initial_items': initialItems.map(wordReviewItemToJson).toList(),
    'dynamic_queue': dynamicQueue.map(wordReviewItemToJson).toList(),
    'answered_results': answeredResults
        .map((result) => result.toJson())
        .toList(),
    'current_index': currentIndex,
  });
}

DecodedWordReviewSessionPayload decodeWordReviewSessionPayload(
  String dataPayload,
) {
  final decoded = Map<String, dynamic>.from(
    jsonDecode(dataPayload) as Map<String, dynamic>,
  );

  final initialItems = _decodeItems(decoded['initial_items']);
  final dynamicQueue = _decodeItems(decoded['dynamic_queue']);
  final answeredResults = _decodeAnsweredResults(decoded['answered_results']);

  return DecodedWordReviewSessionPayload(
    initialItems: initialItems,
    dynamicQueue: dynamicQueue,
    answeredResults: answeredResults,
    currentIndex: _readInt(decoded['current_index']),
  );
}

String encodeKanaReviewSessionPayload({
  required List<ReviewKanaItem> initialItems,
  required List<ReviewKanaItem> dynamicQueue,
  required List<KanaReviewAnsweredResult> answeredResults,
  required int currentIndex,
}) {
  return jsonEncode({
    'initial_items': initialItems.map(kanaReviewItemToJson).toList(),
    'dynamic_queue': dynamicQueue.map(kanaReviewItemToJson).toList(),
    'answered_results': answeredResults
        .map((result) => result.toJson())
        .toList(),
    'current_index': currentIndex,
  });
}

DecodedKanaReviewSessionPayload decodeKanaReviewSessionPayload(
  String dataPayload,
) {
  final decoded = Map<String, dynamic>.from(
    jsonDecode(dataPayload) as Map<String, dynamic>,
  );

  final initialItems = _decodeKanaItems(decoded['initial_items']);
  final dynamicQueue = _decodeKanaItems(decoded['dynamic_queue']);
  final answeredResults = _decodeKanaAnsweredResults(
    decoded['answered_results'],
  );

  return DecodedKanaReviewSessionPayload(
    initialItems: initialItems,
    dynamicQueue: dynamicQueue,
    answeredResults: answeredResults,
    currentIndex: _readInt(decoded['current_index']),
  );
}

Map<String, dynamic> wordReviewItemToJson(WordReviewItem item) {
  return {
    'word_state': item.studyWord.toMap(),
    'word_detail': {
      'id': item.wordDetail.word.id,
      'word': item.wordDetail.word.word,
      'reading': item.wordDetail.word.reading,
      'romaji': item.wordDetail.word.romaji,
      'pitch_accent': item.wordDetail.word.pitchAccent,
      'jlpt_level': item.wordDetail.word.jlptLevel,
      'part_of_speech': item.wordDetail.word.partOfSpeech,
      'transitivity': item.wordDetail.word.transitivity,
      'primary_meaning': item.wordDetail.word.primaryMeaning,
      'has_audio': item.wordDetail.word.hasAudio,
      'rich_content': jsonDecode(item.wordDetail.richContent.toJsonString()),
      'examples': item.wordDetail.examples
          .map(
            (example) => {
              'id': example.id,
              'word_id': example.wordId,
              'japanese': example.japanese,
              'chinese': example.chinese,
              'is_favorited': example.isFavorited,
              'has_audio': example.hasAudio,
              'sort_order': example.sortOrder,
            },
          )
          .toList(),
    },
    'question_type': _wordQuestionTypeToString(item.questionType),
    'audio_source': item.audioSource,
    'meaning': item.meaning,
    'reading': item.reading,
    'options': item.options,
    'cloze_sentence': item.clozeSentence,
  };
}

Map<String, dynamic> kanaReviewItemToJson(ReviewKanaItem item) {
  return {
    'kana_letter': item.kanaLetter.toMap(),
    'learning_state': item.learningState.toMap(),
    'audio_filename': item.audioFilename,
    'question_type': _kanaQuestionTypeToString(item.questionType),
    'options': item.options,
    'counterpart_letter': item.counterpartLetter?.toMap(),
  };
}

WordReviewItem wordReviewItemFromJson(Map<String, dynamic> json) {
  return WordReviewItem(
    studyWord: StudyWord.fromMap(
      Map<String, dynamic>.from(json['word_state'] as Map),
    ),
    wordDetail: WordDetail.fromJson(
      Map<String, dynamic>.from(json['word_detail'] as Map),
    ),
    questionType: wordReviewQuestionTypeFromApi(
      json['question_type'] as String? ?? 'word_to_meaning',
    ),
    audioSource: json['audio_source'] as String?,
    meaning: json['meaning'] as String?,
    reading: json['reading'] as String?,
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((entry) => entry.toString())
        .toList(),
    clozeSentence: json['cloze_sentence'] as String?,
  );
}

ReviewKanaItem kanaReviewItemFromJson(Map<String, dynamic> json) {
  return ReviewKanaItem(
    kanaLetter: KanaLetter.fromMap(
      Map<String, dynamic>.from(json['kana_letter'] as Map),
    ),
    learningState: KanaLearningState.fromMap(
      Map<String, dynamic>.from(json['learning_state'] as Map),
    ),
    audioFilename: json['audio_filename'] as String?,
    questionType: reviewQuestionTypeFromApi(
      json['question_type'] as String? ?? 'hiragana_to_romaji',
    ),
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((entry) => entry.toString())
        .toList(),
    counterpartLetter: json['counterpart_letter'] == null
        ? null
        : KanaLetter.fromMap(
            Map<String, dynamic>.from(json['counterpart_letter'] as Map),
          ),
  );
}

String _wordQuestionTypeToString(WordReviewQuestionType type) {
  switch (type) {
    case WordReviewQuestionType.audioToMeaning:
      return 'audio_to_meaning';
    case WordReviewQuestionType.kanjiToReading:
      return 'kanji_to_reading';
    case WordReviewQuestionType.meaningToSpelling:
      return 'meaning_to_spelling';
    case WordReviewQuestionType.wordToMeaning:
      return 'word_to_meaning';
    case WordReviewQuestionType.clozeTest:
      return 'cloze_test';
  }
}

String _kanaQuestionTypeToString(ReviewQuestionType type) {
  switch (type) {
    case ReviewQuestionType.romajiToHiragana:
      return 'romaji_to_hiragana';
    case ReviewQuestionType.katakanaToRomaji:
      return 'katakana_to_romaji';
    case ReviewQuestionType.romajiToKatakana:
      return 'romaji_to_katakana';
    case ReviewQuestionType.hiraganaToKatakana:
      return 'hiragana_to_katakana';
    case ReviewQuestionType.katakanaToHiragana:
      return 'katakana_to_hiragana';
    case ReviewQuestionType.hiraganaToRomaji:
      return 'hiragana_to_romaji';
  }
}

List<WordReviewItem> _decodeItems(dynamic value) {
  if (value is! List<dynamic>) {
    return const [];
  }

  return value
      .map(
        (entry) =>
            wordReviewItemFromJson(Map<String, dynamic>.from(entry as Map)),
      )
      .toList();
}

List<ReviewKanaItem> _decodeKanaItems(dynamic value) {
  if (value is! List<dynamic>) {
    return const [];
  }

  return value
      .map(
        (entry) =>
            kanaReviewItemFromJson(Map<String, dynamic>.from(entry as Map)),
      )
      .toList();
}

List<WordReviewAnsweredResult> _decodeAnsweredResults(dynamic value) {
  if (value is! List<dynamic>) {
    return const [];
  }

  return value
      .map(
        (entry) => WordReviewAnsweredResult.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      )
      .where((entry) => entry.wordId.isNotEmpty)
      .toList();
}

List<KanaReviewAnsweredResult> _decodeKanaAnsweredResults(dynamic value) {
  if (value is! List<dynamic>) {
    return const [];
  }

  return value
      .map(
        (entry) => KanaReviewAnsweredResult.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      )
      .where((entry) => entry.kanaId > 0)
      .toList();
}

int _readInt(dynamic value) {
  return switch (value) {
    int number => number,
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}
