import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../data/models/word_audio.dart';
import '../../../data/models/example_audio.dart';
import '../../../services/audio_service.dart';
import '../../../services/audio_service_provider.dart';
import '../../word_list/controller/word_list_controller.dart';
import '../state/word_detail_state.dart';

/// WordDetailController Provider
final wordDetailControllerProvider =
    NotifierProvider<WordDetailController, WordDetailState>(
      WordDetailController.new,
    );

/// 单词详情控制器
class WordDetailController extends Notifier<WordDetailState> {
  @override
  WordDetailState build() => const WordDetailState();

  WordRepository get _repository => ref.read(wordRepositoryProvider);

  /// 获取音频服务
  AudioService get _audioService => ref.read(audioServiceProvider);

  /// 加载单词详情
  Future<void> loadWordDetail(int wordId) async {
    try {
      logger.info('开始加载单词详情: $wordId');
      state = state.copyWith(isLoading: true, error: null, wordId: wordId);

      final detail = await _repository.getWordDetail(wordId);

      if (detail == null) {
        state = state.copyWith(isLoading: false, error: '单词不存在');
        logger.warning('单词不存在: $wordId');
        return;
      }

      state = state.copyWith(isLoading: false, detail: detail);

      logger.info(
        '单词详情加载成功: ${detail.word.word} '
        '(${detail.meanings.length}个释义, ${detail.examples.length}个例句)',
      );
    } catch (e, stackTrace) {
      logger.error('加载单词详情失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 刷新当前单词详情
  Future<void> refresh() async {
    if (state.wordId != null) {
      await loadWordDetail(state.wordId!);
    }
  }

  /// 清空状态
  void clear() {
    state = const WordDetailState();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  // ==================== 音频播放 ====================

  /// 播放单词音频
  Future<void> playWordAudio(WordAudio audio) async {
    try {
      logger.info('播放单词音频: ${audio.audioFilename}');
      await _audioService.playWordAudio(audio);
    } catch (e, stackTrace) {
      logger.error('播放单词音频失败', e, stackTrace);
      state = state.copyWith(error: '播放音频失败: $e');
    }
  }

  /// 播放例句音频
  Future<void> playExampleAudio(ExampleAudio audio) async {
    try {
      logger.info('播放例句音频: ${audio.audioFilename}');
      await _audioService.playExampleAudio(audio);
    } catch (e, stackTrace) {
      logger.error('播放例句音频失败', e, stackTrace);
      state = state.copyWith(error: '播放音频失败: $e');
    }
  }

  /// 停止音频播放
  Future<void> stopAudio() async {
    try {
      await _audioService.stop();
    } catch (e, stackTrace) {
      logger.error('停止音频失败', e, stackTrace);
    }
  }

  /// 暂停音频播放
  Future<void> pauseAudio() async {
    try {
      await _audioService.pause();
    } catch (e, stackTrace) {
      logger.error('暂停音频失败', e, stackTrace);
    }
  }
}
