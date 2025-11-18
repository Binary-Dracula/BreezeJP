import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
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
}
