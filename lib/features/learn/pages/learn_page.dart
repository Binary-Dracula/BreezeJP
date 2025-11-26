import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/learn_controller.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../state/learn_state.dart';
import '../widgets/word_card.dart';
import '../widgets/example_card.dart';
import '../../../core/constants/app_constants.dart';

/// 学习页面 - 背单词主界面
class LearnPage extends ConsumerStatefulWidget {
  final String? jlptLevel;

  const LearnPage({super.key, this.jlptLevel});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  late PageController _pageController;
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    // 初始化 PageController
    _pageController = PageController();
    // 记录会话开始时间
    _sessionStartTime = DateTime.now();

    // 页面加载时获取单词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(learnControllerProvider.notifier)
          .loadWords(
            jlptLevel: widget.jlptLevel,
            count: AppConstants.defaultLearnCount,
          );
    });
  }

  @override
  void dispose() {
    // 保存学习统计数据
    if (_sessionStartTime != null) {
      // 计算学习时长
      final duration = DateTime.now().difference(_sessionStartTime!);
      final durationMs = duration.inMilliseconds;

      // 获取已学习单词数
      final state = ref.read(learnControllerProvider);
      final learnedCount = state.learnedWordIds.length;

      // 调用 LearnController 方法更新统计
      // 注意：这里不能使用 async/await，因为 dispose 是同步的
      // 但 updateDailyStats 内部会处理异步操作
      if (learnedCount > 0 || durationMs > 0) {
        ref
            .read(learnControllerProvider.notifier)
            .updateDailyStats(durationMs: durationMs);
      }
    }

    // 释放 PageController
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learnControllerProvider);
    final controller = ref.read(learnControllerProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 检查当前批次是否学习完成（需要已加载过数据）
    if (state.isBatchCompleted) {
      return _buildFinishedScreen(controller, theme, l10n);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.jlptLevel != null
              ? '${l10n.learning} ${widget.jlptLevel}'
              : l10n.learnWords,
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          // 序号指示器（显示"第 X 个"）
          if (state.studyQueue.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '第 ${state.currentIndex + 1} 个',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(state, controller, theme, l10n),
    );
  }

  Widget _buildFinishedScreen(
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.learningFinished,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 48),
            // 返回首页按钮
            FilledButton.icon(
              onPressed: () {
                controller.endSession();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.home),
              label: Text(l10n.backToHome),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    LearnState state,
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.loadingWords,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(fontSize: 16, color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                controller.loadWords(jlptLevel: widget.jlptLevel);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.studyQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noWordsToLearn,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // 使用 PageView.builder 实现水平滑动
    return PageView.builder(
      controller: _pageController,
      itemCount: state.studyQueue.length,
      onPageChanged: (index) {
        // 触觉反馈
        HapticFeedback.lightImpact();
        // 调用 LearnController.onPageChanged
        controller.onPageChanged(index);
      },
      itemBuilder: (context, index) {
        // 构建单词页面（在下一个子任务中实现）
        return _buildWordPage(state, controller, theme, l10n, index);
      },
    );
  }

  /// 构建单词页面（用于 PageView.builder 的 itemBuilder）
  Widget _buildWordPage(
    LearnState state,
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
    int index,
  ) {
    // 获取指定索引的单词详情
    if (index >= state.studyQueue.length) {
      return const SizedBox.shrink();
    }

    final studyWord = state.studyQueue[index];
    final wordDetail = state.wordDetails[studyWord.wordId];

    if (wordDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // 使用 SingleChildScrollView 包裹内容，支持垂直滚动
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 单词卡片
          WordCard(
            wordDetail: wordDetail,
            isPlayingAudio: state.isPlayingWordAudio,
            onPlayAudio: controller.playWordAudio,
          ),

          const SizedBox(height: 24),

          // 例句列表
          ...wordDetail.examples.asMap().entries.map((entry) {
            final exampleIndex = entry.key;
            final example = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ExampleCard(
                example: example,
                index: exampleIndex,
                isPlaying:
                    state.isPlayingExampleAudio &&
                    state.playingExampleIndex == exampleIndex,
                onPlayAudio: () => controller.playExampleAudio(exampleIndex),
              ),
            );
          }),
        ],
      ),
    );
  }
}
