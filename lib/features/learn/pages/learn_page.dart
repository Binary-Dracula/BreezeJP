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
            const SizedBox(height: 16),
            Text(
              l10n.learningFinishedDesc,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 48),
            // 继续学习按钮
            FilledButton.icon(
              onPressed: () {
                controller.loadWords(jlptLevel: widget.jlptLevel);
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.continueLearning),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 返回首页按钮
            OutlinedButton.icon(
              onPressed: () {
                controller.endSession();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.home),
              label: Text(l10n.backToHome),
              style: OutlinedButton.styleFrom(
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

    // 根据模式显示不同的 UI
    if (state.currentMode == StudyMode.review && !state.showAnswer) {
      // 复习模式 - 提问阶段：只显示单词
      return _buildReviewQuestionView(state, controller, theme, l10n);
    } else {
      // 学习模式 或 复习模式的回答阶段：显示完整内容
      return _buildFullContentView(state, controller, theme, l10n);
    }
  }

  /// 复习模式 - 提问阶段：只显示单词大字
  Widget _buildReviewQuestionView(
    LearnState state,
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final wordDetail = state.currentWordDetail!;

    return GestureDetector(
      onTap: controller.showAnswer,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 单词大字
              Text(
                    wordDetail.word.word,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                  ),
              const SizedBox(height: 24),
              // 提示文字
              Text(
                l10n.tapToShowAnswer,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 学习模式 或 复习回答阶段：显示完整内容
  Widget _buildFullContentView(
    LearnState state,
    LearnController controller,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
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

    // 复习模式的提问阶段：不显示底部栏（点击屏幕显示答案）
    if (state.currentMode == StudyMode.review && !state.showAnswer) {
      return const SizedBox.shrink();
    }

    // 判断是否是最后一个单词
    final isLastWord = state.currentIndex >= state.studyQueue.length - 1;

    // 学习模式：显示"下一个"或"完成"按钮
    if (state.currentMode == StudyMode.learn) {
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
          child: FilledButton(
            onPressed: () => controller.submitAnswer(ReviewRating.good),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isLastWord ? l10n.finish : l10n.nextWord,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // 复习模式的回答阶段：显示评分按钮
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
