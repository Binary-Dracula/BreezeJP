import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/learning_status.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/learn_controller.dart';
import '../state/learn_state.dart';
import '../../common/widgets/issue_report_sheet.dart';
import '../../word_detail/widgets/word_detail_content.dart';

/// 学习页面（2.0 — 批次式学习，AnimatedSwitcher 无滑动翻页）
class LearnPage extends ConsumerStatefulWidget {
  final String bookId;

  const LearnPage({super.key, required this.bookId});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(learnControllerProvider.notifier).startLearning(widget.bookId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learnControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    ref.listen(learnControllerProvider, (previous, next) {
      if (next.isBatchComplete && !(previous?.isBatchComplete ?? false)) {
        _showBatchCompletedDialog(context, l10n);
      }
      if (next.isBookComplete && !(previous?.isBookComplete ?? false)) {
        _showNoMoreWordsDialog(context, l10n);
      }
      if (next.isResumed && !(previous?.isResumed ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢复上次学习进度'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      if (next.isBookUnavailableForNextBatch &&
          !(previous?.isBookUnavailableForNextBatch ?? false)) {
        _showBookUnavailableDialog(context, l10n);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitLearnPage(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(context, state, l10n),
                  Expanded(child: _buildContent(context, state, l10n)),
                ],
              ),
              if (!state.isLoading && !state.isEmpty)
                Positioned(
                  right: 10,
                  bottom: 104,
                  child: _buildActionRail(context, state, l10n),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    LearnState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final hasWords = state.words.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _exitLearnPage(context),
          ),
          const Spacer(),
          if (hasWords)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${state.currentIndex + 1} / ${state.words.length}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          if (hasWords)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              onPressed: () {
                final wordDetail = state.currentWordDetail;
                if (wordDetail == null) return;
                IssueReportSheet.show(
                  context: context,
                  ref: ref,
                  contentType: 'word',
                  contentId: wordDetail.word.id,
                  contentSnapshot: {
                    'word': wordDetail.word.toMap(),
                    'rich_content': wordDetail.richContent.toJsonString(),
                  },
                  displayTitle: wordDetail.word.word,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LearnState state,
    AppLocalizations l10n,
  ) {
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
                    .startLearning(widget.bookId);
              },
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return Center(child: Text(l10n.learnNoWordsAvailable));
    }

    final wordDetail = state.currentWordDetail;
    if (wordDetail == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: WordDetailContent(
        key: ValueKey(state.currentIndex),
        wordDetail: wordDetail,
      ),
    );
  }

  Widget _buildActionRail(
    BuildContext context,
    LearnState state,
    AppLocalizations l10n,
  ) {
    final controller = ref.read(learnControllerProvider.notifier);
    final currentStatus = state.currentWordState();
    final isIgnored = currentStatus == LearningStatus.ignored;
    final isMastered = currentStatus == LearningStatus.mastered;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RailActionButton(
                    icon: Icons.visibility_off_outlined,
                    label: l10n.wordActionIgnore,
                    color: const Color(0xFFF59E0B),
                    enabled: !isIgnored,
                    onPressed: () => controller.markCurrentIgnored(),
                  ),
                  const SizedBox(height: 12),
                  _RailActionButton(
                    icon: Icons.check_circle_outline,
                    label: l10n.wordActionMastered,
                    color: const Color(0xFF34D399),
                    enabled: !isMastered,
                    emphasized: true,
                    onPressed: () => controller.markCurrentMastered(),
                  ),
                  const SizedBox(height: 12),
                  _RailActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: l10n.previous,
                    color: const Color(0xFF64748B),
                    enabled: state.currentIndex > 0,
                    onPressed: () => controller.goToPrev(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatchCompletedDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.learnBatchCompletedTitle),
        content: Text(l10n.learnBatchCompletedContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _exitLearnPage(context);
            },
            child: Text(l10n.learnBatchCompletedExit),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(learnControllerProvider.notifier).continueNextBatch();
            },
            child: Text(l10n.learnBatchCompletedContinue),
          ),
        ],
      ),
    );
  }

  void _showNoMoreWordsDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.learnNoMoreWordsTitle),
        content: Text(l10n.learnNoMoreWordsContent),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _exitLearnPage(context);
            },
            child: Text(l10n.learnBatchCompletedExit),
          ),
        ],
      ),
    );
  }

  void _showBookUnavailableDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.learnBookUnavailableTitle),
        content: Text(l10n.learnBookUnavailableContent),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(learnControllerProvider.notifier)
                  .acknowledgeBookUnavailableForNextBatch();
              Navigator.of(dialogContext).pop();
              _exitLearnPage(context);
            },
            child: Text(l10n.learnBatchCompletedExit),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(learnControllerProvider.notifier)
                  .acknowledgeBookUnavailableForNextBatch();
              Navigator.of(dialogContext).pop();
              context.go('/book-selection');
            },
            child: Text(l10n.learnBookUnavailableSelectBook),
          ),
        ],
      ),
    );
  }

  void _exitLearnPage(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }
}

class _RailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool emphasized;
  final VoidCallback onPressed;

  const _RailActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : Colors.grey.shade400;
    final foregroundColor = emphasized ? Colors.white : effectiveColor;
    final backgroundColor = emphasized
        ? effectiveColor
        : Colors.white.withValues(alpha: enabled ? 0.72 : 0.5);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Material(
            color: backgroundColor,
            elevation: emphasized ? 5 : 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, color: foregroundColor, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF475569) : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
