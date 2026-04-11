import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/learn_controller.dart';
import '../state/learn_state.dart';
import '../widgets/word_action_bar.dart';
import '../widgets/word_examples_section.dart';
import '../widgets/word_header.dart';
import '../widgets/word_meanings_section.dart';
import '../widgets/conjugation_list.dart';

/// 学习页面（2.0 — 书籍顺序学习）
class LearnPage extends ConsumerStatefulWidget {
  final String bookId;

  const LearnPage({super.key, required this.bookId});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(learnControllerProvider.notifier)
          .startBookLearning(widget.bookId);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handlePop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, state, l10n),
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        ),
        bottomNavigationBar: _buildWordActionBar(state),
      ),
    );
  }

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
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await ref.read(learnControllerProvider.notifier).endSession();
              if (context.mounted) {
                context.pop();
              }
            },
          ),
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
                    .startBookLearning(widget.bookId);
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
              WordMeaningsSection(richContent: wordDetail.richContent),
              WordExamplesSection(examples: wordDetail.examples),
              ConjugationList(conjugations: wordDetail.richContent.conjugations),
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
                  context.pop();
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
