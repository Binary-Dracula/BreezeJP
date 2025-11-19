import 'word.dart';
import 'word_meaning.dart';
import 'word_audio.dart';
import 'example_sentence.dart';
import 'example_audio.dart';

/// 单词详情（包含所有关联数据）
class WordDetail {
  final Word word;
  final List<WordMeaning> meanings;
  final List<WordAudio> audios;
  final List<ExampleSentenceWithAudio> examples;

  WordDetail({
    required this.word,
    required this.meanings,
    required this.audios,
    required this.examples,
  });

  /// 获取主要释义（第一个）
  String? get primaryMeaning =>
      meanings.isNotEmpty ? meanings.first.meaningCn : null;

  /// 获取所有释义文本
  List<String> get allMeanings => meanings.map((m) => m.meaningCn).toList();

  /// 获取主要音频对象
  WordAudio? get primaryAudio => audios.isNotEmpty ? audios.first : null;

  /// 获取主要音频文件名
  String? get primaryAudioFilename =>
      audios.isNotEmpty ? audios.first.audioFilename : null;

  /// 获取音频文件路径（已废弃，建议使用 AudioService）
  /// 注意：此方法仅返回本地路径，不支持在线 URL
  /// 推荐使用 AudioService.playWordAudio(primaryAudio) 代替
  @Deprecated('使用 AudioService.playWordAudio() 代替')
  String? get primaryAudioPath => primaryAudioFilename != null
      ? 'assets/audio/words/$primaryAudioFilename'
      : null;
}

/// 例句及其音频（组合）
class ExampleSentenceWithAudio {
  final ExampleSentence sentence;
  final ExampleAudio? audio;

  ExampleSentenceWithAudio({required this.sentence, this.audio});

  /// 获取音频文件路径（已废弃，建议使用 AudioService）
  /// 注意：此方法仅返回本地路径，不支持在线 URL
  /// 推荐使用 AudioService.playExampleAudio(audio) 代替
  @Deprecated('使用 AudioService.playExampleAudio() 代替')
  String? get audioPath => audio?.audioFilename != null
      ? 'assets/audio/examples/${audio!.audioFilename}'
      : null;
}
