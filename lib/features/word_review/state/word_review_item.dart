import '../../../data/models/study_word.dart';
import '../../../data/models/word_detail.dart';

enum WordReviewQuestionType {
  wordToMeaning, // 1. 识别类：显示日语单词（汉字/假名），选中文解释
  audioToMeaning, // 2. 听音：只播放单词音频，选中文含义
  kanjiToReading, // 3. 读音判定：有汉字的单词选平假名读音
  meaningToSpelling, // 4. 拼写：显示释义/发音，乱序假名拼写
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
