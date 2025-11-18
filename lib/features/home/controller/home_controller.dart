import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository.dart';
import '../../word_list/controller/word_list_controller.dart';
import '../state/home_state.dart';

/// HomeController Provider
final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

/// 主页控制器
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  WordRepository get _repository => ref.read(wordRepositoryProvider);

  /// 加载统计信息
  Future<void> loadStatistics() async {
    try {
      logger.info('开始加载统计信息');
      state = state.copyWith(isLoading: true, error: null);

      // 获取各等级单词数量
      final countByLevel = await _repository.getWordCountByLevel();

      // 获取总数
      final totalCount = await _repository.getWordCount();

      state = state.copyWith(
        isLoading: false,
        wordCountByLevel: countByLevel,
        totalWords: totalCount,
      );

      logger.info('统计信息加载成功: 总计 $totalCount 个单词');
      countByLevel.forEach((level, count) {
        logger.debug('  $level: $count 个');
      });
    } catch (e, stackTrace) {
      logger.error('加载统计信息失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 刷新统计信息
  Future<void> refresh() async {
    await loadStatistics();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
