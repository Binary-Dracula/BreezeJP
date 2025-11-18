import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
import '../state/word_list_state.dart';

/// WordRepository Provider
final wordRepositoryProvider = Provider((ref) => WordRepository());

/// WordListController Provider
final wordListControllerProvider =
    NotifierProvider<WordListController, WordListState>(WordListController.new);

/// 单词列表控制器
class WordListController extends Notifier<WordListState> {
  @override
  WordListState build() => const WordListState();

  WordRepository get _repository => ref.read(wordRepositoryProvider);

  /// 加载指定等级的单词
  Future<void> loadWordsByLevel(String jlptLevel) async {
    try {
      logger.info('开始加载 $jlptLevel 单词列表');
      state = state.copyWith(
        isLoading: true,
        error: null,
        currentLevel: jlptLevel,
      );

      final words = await _repository.getWordsByLevel(jlptLevel);
      final count = await _repository.getWordCount(jlptLevel: jlptLevel);

      state = state.copyWith(isLoading: false, words: words, totalCount: count);

      logger.info('$jlptLevel 单词加载成功，共 ${words.length} 个');
    } catch (e, stackTrace) {
      logger.error('加载单词列表失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 加载所有单词（分页）
  Future<void> loadAllWords({int page = 0, int pageSize = 20}) async {
    try {
      logger.info('加载所有单词，页码: $page');
      state = state.copyWith(isLoading: true, error: null);

      final words = await _repository.getAllWords(
        limit: pageSize,
        offset: page * pageSize,
      );
      final count = await _repository.getWordCount();

      state = state.copyWith(
        isLoading: false,
        words: words,
        totalCount: count,
        currentLevel: null,
      );

      logger.info('单词加载成功，共 ${words.length} 个');
    } catch (e, stackTrace) {
      logger.error('加载所有单词失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 搜索单词
  Future<void> searchWords(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = state.copyWith(words: [], error: null);
      return;
    }

    try {
      logger.info('搜索单词: $keyword');
      state = state.copyWith(isLoading: true, error: null);

      final words = await _repository.searchWords(keyword);

      state = state.copyWith(
        isLoading: false,
        words: words,
        totalCount: words.length,
      );

      logger.info('搜索完成，找到 ${words.length} 个结果');
    } catch (e, stackTrace) {
      logger.error('搜索单词失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '搜索失败: $e');
    }
  }

  /// 刷新当前列表
  Future<void> refresh() async {
    if (state.currentLevel != null) {
      await loadWordsByLevel(state.currentLevel!);
    } else {
      await loadAllWords();
    }
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
