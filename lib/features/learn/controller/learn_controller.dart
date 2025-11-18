import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../data/models/word_detail.dart';
import '../../word_list/controller/word_list_controller.dart';
import '../state/learn_state.dart';

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);

/// 学习控制器
class LearnController extends Notifier<LearnState> {
  @override
  LearnState build() => const LearnState();

  WordRepository get _repository => ref.read(wordRepositoryProvider);

  /// 开始学习（随机模式）
  Future<void> startRandomLearning({
    required String jlptLevel,
    int count = 10,
  }) async {
    try {
      logger.info('开始随机学习: $jlptLevel, 数量: $count');
      state = state.copyWith(
        isLoading: true,
        error: null,
        jlptLevel: jlptLevel,
        currentIndex: 0,
        isCompleted: false,
      );

      // 获取随机单词
      final words = await _repository.getRandomWords(
        count: count,
        jlptLevel: jlptLevel,
      );

      if (words.isEmpty) {
        state = state.copyWith(isLoading: false, error: '没有找到单词');
        logger.warning('没有找到 $jlptLevel 单词');
        return;
      }

      // 获取每个单词的详细信息
      final wordDetails = <WordDetail>[];
      for (final word in words) {
        final detail = await _repository.getWordDetail(word.id);
        if (detail != null) {
          wordDetails.add(detail);
        }
      }

      state = state.copyWith(
        isLoading: false,
        words: wordDetails,
        totalWords: wordDetails.length,
      );

      logger.info('学习准备完成，共 ${wordDetails.length} 个单词');
    } catch (e, stackTrace) {
      logger.error('开始学习失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 开始学习（顺序模式）
  Future<void> startSequentialLearning({
    required String jlptLevel,
    int startIndex = 0,
    int count = 10,
  }) async {
    try {
      logger.info('开始顺序学习: $jlptLevel, 起始: $startIndex, 数量: $count');
      state = state.copyWith(
        isLoading: true,
        error: null,
        jlptLevel: jlptLevel,
        currentIndex: 0,
        isCompleted: false,
      );

      // 获取单词列表
      final words = await _repository.getAllWords(
        limit: count,
        offset: startIndex,
      );

      if (words.isEmpty) {
        state = state.copyWith(isLoading: false, error: '没有找到单词');
        return;
      }

      // 获取详细信息
      final wordDetails = <WordDetail>[];
      for (final word in words) {
        final detail = await _repository.getWordDetail(word.id);
        if (detail != null) {
          wordDetails.add(detail);
        }
      }

      state = state.copyWith(
        isLoading: false,
        words: wordDetails,
        totalWords: wordDetails.length,
      );

      logger.info('学习准备完成，共 ${wordDetails.length} 个单词');
    } catch (e, stackTrace) {
      logger.error('开始学习失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 下一个单词
  void nextWord() {
    if (state.hasNext) {
      final newIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: newIndex);
      logger.debug('切换到下一个单词: $newIndex');
    } else {
      // 学习完成
      state = state.copyWith(isCompleted: true);
      logger.info('学习完成！');
    }
  }

  /// 上一个单词
  void previousWord() {
    if (state.hasPrevious) {
      final newIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: newIndex);
      logger.debug('切换到上一个单词: $newIndex');
    }
  }

  /// 跳转到指定单词
  void goToWord(int index) {
    if (index >= 0 && index < state.words.length) {
      state = state.copyWith(currentIndex: index);
      logger.debug('跳转到单词: $index');
    }
  }

  /// 重新开始
  void restart() {
    state = state.copyWith(currentIndex: 0, isCompleted: false);
    logger.info('重新开始学习');
  }

  /// 清空状态
  void clear() {
    state = const LearnState();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
