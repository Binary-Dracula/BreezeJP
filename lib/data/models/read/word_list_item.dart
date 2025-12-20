import '../word.dart';

/// 单词列表项（包含主释义）
class WordListItem {
  final Word word;
  final String? primaryMeaning;

  const WordListItem({required this.word, this.primaryMeaning});
}
