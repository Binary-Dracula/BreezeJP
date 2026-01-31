import '../../../data/models/study_word.dart';
import '../../../data/models/word_detail.dart';

enum WordReviewQuestionType {
  wordToMeaning,
  meaningToWord,
  audioToWord,
  readingToWord,
}

class WordReviewItem {
  final StudyWord studyWord;
  final WordDetail wordDetail;
  final WordReviewQuestionType questionType;
  final String? audioSource;
  final String? meaning;
  final String? reading;

  const WordReviewItem({
    required this.studyWord,
    required this.wordDetail,
    required this.questionType,
    required this.audioSource,
    required this.meaning,
    required this.reading,
  });
}
