import 'word.dart';
import 'word_meaning.dart';

/// 单词选择项（包含基本信息和释义列表）
/// 用于初始选择页展示单词选项
class WordChoice {
  final Word word;
  final List<WordMeaning> meanings;

  const WordChoice({required this.word, this.meanings = const []});

  /// 获取第一个释义（用于显示）
  String? get primaryMeaning =>
      meanings.isNotEmpty ? meanings.first.meaningCn : null;
}
