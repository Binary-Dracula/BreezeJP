import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controller/learn_controller.dart';
import '../state/learn_state.dart';
import '../widgets/word_card.dart';
import '../widgets/example_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.jlptLevel != null ? '学习 ${widget.jlptLevel}' : '学习单词',
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          // 进度指示器
          if (state.words.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${state.currentIndex + 1}/${state.words.length}',
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
      body: _buildBody(state, controller, theme),
      bottomNavigationBar: _buildNavigationBar(state, controller, theme),
    );
  }

  Widget _buildBody(
    LearnState state,
    LearnController controller,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '正在加载单词...',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.currentWord == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '没有可学习的单词',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    final wordDetail = state.currentWord!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
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
                    '例句',
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
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上一个按钮
            ElevatedButton.icon(
              onPressed: state.hasPrevious ? controller.previousWord : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('上一个'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                disabledBackgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurface
                    .withOpacity(0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // 进度指示器
            if (state.words.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.currentIndex + 1} / ${state.words.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

            // 下一个按钮
            ElevatedButton.icon(
              onPressed: state.hasNext ? controller.nextWord : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一个'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurface
                    .withOpacity(0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
