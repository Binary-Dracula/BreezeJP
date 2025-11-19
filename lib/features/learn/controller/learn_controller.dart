import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../data/models/word_detail.dart';
import '../state/learn_state.dart';

/// 学习页面控制器
class LearnController extends Notifier<LearnState> {
  final WordRepository _repository = WordRepository();
  final AudioPlayer _wordAudioPlayer = AudioPlayer();
  final AudioPlayer _exampleAudioPlayer = AudioPlayer();

  @override
  LearnState build() {
    _initAudioPlayers();
    return LearnState();
  }

  void _initAudioPlayers() {
    _wordAudioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlayingWordAudio: false);
      }
    });

    _exampleAudioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(
          isPlayingExampleAudio: false,
          playingExampleIndex: null,
        );
      }
    });
  }

  /// 加载单词列表（按 JLPT 等级）
  Future<void> loadWords({String? jlptLevel, int count = 20}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      logger.info('加载单词列表: jlptLevel=$jlptLevel, count=$count');

      // 获取随机单词
      final words = await _repository.getRandomWords(
        count: count,
        jlptLevel: jlptLevel,
      );

      // 获取每个单词的详情
      final wordDetails = <WordDetail>[];
      for (final word in words) {
        final detail = await _repository.getWordDetail(word.id);
        if (detail != null) {
          wordDetails.add(detail);
        }
      }

      state = state.copyWith(
        words: wordDetails,
        currentIndex: 0,
        isLoading: false,
      );

      logger.info('成功加载 ${wordDetails.length} 个单词');
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载单词失败: $e');
    }
  }

  /// 下一个单词
  void nextWord() {
    if (state.hasNext) {
      _stopAllAudio();
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      logger.info('切换到下一个单词: ${state.currentIndex + 1}/${state.words.length}');
    }
  }

  /// 上一个单词
  void previousWord() {
    if (state.hasPrevious) {
      _stopAllAudio();
      state = state.copyWith(currentIndex: state.currentIndex - 1);
      logger.info('切换到上一个单词: ${state.currentIndex + 1}/${state.words.length}');
    }
  }

  /// 播放单词音频
  Future<void> playWordAudio() async {
    try {
      final currentWord = state.currentWord;
      if (currentWord == null || currentWord.primaryAudioPath == null) {
        logger.warning('没有可播放的单词音频');
        return;
      }

      await _exampleAudioPlayer.stop();
      state = state.copyWith(
        isPlayingExampleAudio: false,
        playingExampleIndex: null,
      );

      if (state.isPlayingWordAudio) {
        await _wordAudioPlayer.stop();
        state = state.copyWith(isPlayingWordAudio: false);
      } else {
        state = state.copyWith(isPlayingWordAudio: true);
        await _wordAudioPlayer.setAsset(currentWord.primaryAudioPath!);
        await _wordAudioPlayer.play();
        logger.info('播放单词音频: ${currentWord.word.word}');
      }
    } catch (e, stackTrace) {
      logger.error('播放单词音频失败', e, stackTrace);
      state = state.copyWith(isPlayingWordAudio: false);
    }
  }

  /// 播放例句音频
  Future<void> playExampleAudio(int exampleIndex) async {
    try {
      final currentWord = state.currentWord;
      if (currentWord == null || exampleIndex >= currentWord.examples.length) {
        return;
      }

      final example = currentWord.examples[exampleIndex];
      if (example.audioPath == null) {
        logger.warning('没有可播放的例句音频');
        return;
      }

      await _wordAudioPlayer.stop();
      state = state.copyWith(isPlayingWordAudio: false);

      if (state.isPlayingExampleAudio &&
          state.playingExampleIndex == exampleIndex) {
        await _exampleAudioPlayer.stop();
        state = state.copyWith(
          isPlayingExampleAudio: false,
          playingExampleIndex: null,
        );
      } else {
        state = state.copyWith(
          isPlayingExampleAudio: true,
          playingExampleIndex: exampleIndex,
        );
        await _exampleAudioPlayer.setAsset(example.audioPath!);
        await _exampleAudioPlayer.play();
        logger.info('播放例句音频: 例句 ${exampleIndex + 1}');
      }
    } catch (e, stackTrace) {
      logger.error('播放例句音频失败', e, stackTrace);
      state = state.copyWith(
        isPlayingExampleAudio: false,
        playingExampleIndex: null,
      );
    }
  }

  /// 停止所有音频
  void _stopAllAudio() {
    _wordAudioPlayer.stop();
    _exampleAudioPlayer.stop();
    state = state.copyWith(
      isPlayingWordAudio: false,
      isPlayingExampleAudio: false,
      playingExampleIndex: null,
    );
  }
}

/// Provider for LearnController
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  () {
    return LearnController();
  },
);
