import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/tracking/page_duration_tracking_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/learn_controller.dart';
import '../state/learn_state.dart';
import '../widgets/word_action_bar.dart';
import '../widgets/word_examples_section.dart';
import '../widgets/word_header.dart';
import '../widgets/word_meanings_section.dart';
import '../widgets/conjugation_list.dart';

/// 学习页面
/// 全屏展示单词详情，支持左右滑动切换单词
class LearnPage extends ConsumerStatefulWidget {
  final int initialWordId;

  const LearnPage({super.key, required this.initialWordId});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage>
    with PageDurationTrackingMixin<LearnPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 页面加载时初始化学习
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(learnControllerProvider.notifier)
          .initWithWord(widget.initialWordId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learnControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    // 监听路径结束状态
    ref.listen(learnControllerProvider, (previous, next) {
      if (next.pathEnded && !(previous?.pathEnded ?? false)) {
        _showPathEndedDialog(context, l10n);
      }
    });

    return WillPopScope(
      onWillPop: _handlePop,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 顶部操作栏
              _buildTopBar(context, state, l10n),
              // 内容区域
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        ),
        bottomNavigationBar: _buildWordActionBar(state),
      ),
    );
  }

  /// 顶部操作栏
  Widget _buildTopBar(
    BuildContext context,
    LearnState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await ref.read(learnControllerProvider.notifier).endSession();
              if (context.mounted) {
                context.pop();
              }
            },
          ),
          // 已学计数
          if (state.learnedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.learnedCount(state.learnedCount),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, LearnState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(learnControllerProvider.notifier)
                    .initWithWord(widget.initialWordId);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return const Center(child: Text('没有可学习的单词'));
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        ref.read(learnControllerProvider.notifier).onPageChanged(index);
      },
      itemCount: state.studyQueue.length,
      itemBuilder: (context, index) {
        final wordDetail = state.studyQueue[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WordHeader(wordDetail: wordDetail),
              WordMeaningsSection(meanings: wordDetail.meanings),
              WordExamplesSection(examples: wordDetail.examples),
              ConjugationList(conjugations: wordDetail.conjugations),
              if (state.isLoadingMore && index == state.studyQueue.length - 1)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildWordActionBar(LearnState state) {
    if (state.isLoading || state.isEmpty) return null;

    final currentWord = state.currentWordDetail;
    if (currentWord == null) return null;

    final controller = ref.read(learnControllerProvider.notifier);

    return WordActionBar(
      userState: currentWord.userState,
      onAddToReview: () {
        controller.addCurrentWordToReview();
      },
      onQuickMaster: () {
        controller.quickMasterCurrentWord();
      },
      onMarkMastered: () {
        controller.markCurrentWordAsMastered();
      },
      onToggleIgnored: () {
        controller.toggleCurrentWordIgnored();
      },
      onRestoreLearning: () {
        controller.onRestoreLearningTapped(currentWord.word.id);
      },
    );
  }

  /// 显示路径结束对话框
  void _showPathEndedDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.pathEndedTitle),
        content: Text(l10n.pathEndedContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(learnControllerProvider.notifier).endSession().then((_) {
                if (context.mounted) {
                  context.go('/initial-choice');
                }
              });
            },
            child: Text(l10n.chooseNewPath),
          ),
        ],
      ),
    );
  }

  Future<bool> _handlePop() async {
    await ref.read(learnControllerProvider.notifier).endSession();
    return true;
  }
}
