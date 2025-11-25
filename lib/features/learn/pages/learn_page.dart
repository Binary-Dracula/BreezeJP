import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controller/learn_controller.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../state/learn_state.dart';
import '../widgets/word_card.dart';
import '../widgets/example_card.dart';
import '../../../data/models/study_log.dart';

/// 学习页面 - 背单词主界面
class LearnPage extends ConsumerStatefulWidget {
  final String? jlptLevel;

  const LearnPage({super.key, this.jlptLevel});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时获取单词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(learnControllerProvider.notifier)
          .loadWords(jlptLevel: widget.jlptLevel, count: 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learnControllerProvider);
    final controller = ref.read(learnControllerProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 检查是否完成
    if (state.isFinished) {
      // 延迟弹出对话框，避免在 build 中直接调用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishedDialog(context, controller, l10n);
      });
      return _buildFinishedScreen(theme, l10n);
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
          // 进度指示器
          if (state.studyQueue.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${state.currentIndex + 1}/${state.studyQueue.length}',
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
      bottomNavigationBar: _buildNavigationBar(state, controller, theme, l10n),
    );
  }

  Widget _buildFinishedScreen(ThemeData theme, AppLocalizations l10n) {
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
            const SizedBox(height: 16),
            Text(
              l10n.learningFinishedDesc,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFinishedDialog(
    BuildContext context,
    LearnController controller,
    AppLocalizations l10n,
  ) async {
    // 避免重复弹出
    if (!mounted) return;

    // 检查是否已经弹出过 (可以通过状态控制，这里简化处理)
    // 更好的方式是在 state 中增加一个字段标记是否已显示完成对话框
    // 但由于 isFinished 状态持续存在，addPostFrameCallback 会一直调用
    // 所以我们需要一个简单的方式来防止无限弹窗
    // 这里我们假设用户点击后会改变状态或导航离开

    // 实际上，由于 addPostFrameCallback 会在每一帧后调用如果 build 被触发
    // 我们应该只在状态变为 finished 的那一刻触发
    // 为了简单起见，我们可以在这里不做处理，而是依靠 showDialog 的模态特性
    // 并且在对话框关闭前不进行其他操作

    // 但是为了防止重复弹窗，我们可以检查是否已经有对话框打开
    // 或者在 controller 中增加一个 flag

    // 让我们先简单实现，如果遇到问题再优化

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.continueLearningTitle),
        content: Text(l10n.continueLearningContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(); // 返回主页
            },
            child: Text(l10n.restABit),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              controller.loadWords(jlptLevel: widget.jlptLevel);
            },
            child: Text(l10n.continueLearning),
          ),
        ],
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

    if (state.currentWordDetail == null) {
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

    final wordDetail = state.currentWordDetail!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 单词卡片
          WordCard(
                wordDetail: wordDetail,
                isPlayingAudio: state.isPlayingWordAudio,
                onPlayAudio: controller.playWordAudio,
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOut,
              ),

          const SizedBox(height: 24),

          // 例句标题
          if (wordDetail.examples.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.examples,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 例句列表
            ...wordDetail.examples.asMap().entries.map((entry) {
              final index = entry.key;
              final example = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    ExampleCard(
                          example: example,
                          index: index,
                          isPlaying:
                              state.isPlayingExampleAudio &&
                              state.playingExampleIndex == index,
                          onPlayAudio: () => controller.playExampleAudio(index),
                        )
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: Duration(
                            milliseconds: (100 * (index + 1)).toInt(),
                          ),
                        )
                        .slideX(
                          begin: 0.2,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOut,
                        ),
              );
            }),
          ],

          const SizedBox(height: 80), // 底部导航栏的空间
        ],
      ),
    );
  }

  Widget _buildNavigationBar(
    LearnState state,
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    // 如果正在加载或没有数据，不显示底部栏
    if (state.isLoading || state.currentWordDetail == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAnswerButton(
              context,
              l10n.ratingAgain,
              l10n.ratingAgainSub,
              const Color(0xFFF44336),
              () => controller.submitAnswer(ReviewRating.again),
            ),
            _buildAnswerButton(
              context,
              l10n.ratingHard,
              l10n.ratingHardSub,
              const Color(0xFFFF9800),
              () => controller.submitAnswer(ReviewRating.hard),
            ),
            _buildAnswerButton(
              context,
              l10n.ratingGood,
              l10n.ratingGoodSub,
              const Color(0xFF4CAF50),
              () => controller.submitAnswer(ReviewRating.good),
            ),
            _buildAnswerButton(
              context,
              l10n.ratingEasy,
              l10n.ratingEasySub,
              const Color(0xFF2196F3),
              () => controller.submitAnswer(ReviewRating.easy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButton(
    BuildContext context,
    String label,
    String subLabel,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withValues(alpha: 0.5)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
