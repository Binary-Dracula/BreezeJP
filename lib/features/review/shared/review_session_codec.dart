import 'dart:convert';

import '../../word_review/state/word_review_item.dart';
import '../../word_review/state/word_review_state.dart';

Map<String, dynamic> encodeWordReviewSessionUpdate({
  required String sessionId,
  required WordReviewState state,
  required bool isFinished,
}) {
  return {
    'session_id': sessionId,
    'current_index': state.currentIndex,
    'current_phase': state.currentPhase.name,
    'has_mistake_on_current': state.hasMistakeOnCurrent,
    'items': state.items.map(_wordItemToJson).toList(),
    'is_finished': isFinished,
  };
}

Map<String, dynamic> _wordItemToJson(WordReviewItem item) {
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
  };
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
