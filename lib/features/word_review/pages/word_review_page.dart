import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tracking/page_duration_tracking_mixin.dart';
import '../../../data/models/study_log.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_service_provider.dart';
import '../controller/word_review_controller.dart';
import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

class WordReviewPage extends ConsumerStatefulWidget {
  const WordReviewPage({super.key});

  @override
  ConsumerState<WordReviewPage> createState() => _WordReviewPageState();
}

class _WordReviewPageState extends ConsumerState<WordReviewPage>
    with PageDurationTrackingMixin<WordReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordReviewControllerProvider.notifier).loadReview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(wordReviewControllerProvider);

    if (state.isLoading) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (state.error != null) {
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
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.loadFailed(state.error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(wordReviewControllerProvider.notifier)
                          .loadReview(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (state.isEmpty || state.isAllFinished) {
      final msg = state.isEmpty
          ? l10n.wordReviewEmpty
          : l10n.wordReviewFinished;
      final icon = state.isEmpty
          ? Icons.inbox_outlined
          : Icons.check_circle_outline;
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: state.isEmpty ? Colors.grey : Colors.green,
                ),
                const SizedBox(height: 12),
                Text(msg, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                if (state.isAllFinished)
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(wordReviewControllerProvider.notifier)
                          .endSession();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(l10n.backToHome),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final currentItem = state.currentItem;
    if (currentItem == null) return const SizedBox.shrink();

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
        appBar: AppBar(
          title: Text(_titleForType(currentItem.questionType, l10n)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey.shade200,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 进度指示文本
              Text(
                '${state.currentIndex + 1} / ${state.items.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 24),

              // 顶部：问题提示区 / 卡片本身内容
              _QuestionPromptArea(item: currentItem),

              const Spacer(),

              // 底部：选项区 OR 评价区
              if (state.currentPhase == ReviewCardPhase.testing)
                _OptionsArea(
                  options: state.currentOptions,
                  hasMistake: state.hasMistakeOnCurrent,
                  onSelect: (val) => ref
                      .read(wordReviewControllerProvider.notifier)
                      .submitObjectiveAnswer(val),
                )
              else
                _RatingArea(
                  item: currentItem,
                  onRate: (rating) => ref
                      .read(wordReviewControllerProvider.notifier)
                      .submitSubjectiveRating(rating),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handlePop() async {
    await ref.read(wordReviewControllerProvider.notifier).endSession();
    return true;
  }
}

class _QuestionPromptArea extends ConsumerWidget {
  final WordReviewItem item;

  const _QuestionPromptArea({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.questionType) {
      case WordReviewQuestionType.meaningToWord:
        return Center(
          child: Text(
            item.meaning ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        );
      case WordReviewQuestionType.audioToWord:
        return Center(
          child: IconButton(
            iconSize: 64,
            color: Theme.of(context).primaryColor,
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              final src = item.audioSource ?? '';
              if (src.isNotEmpty) {
                ref.read(audioServiceProvider).playAudio(src);
              }
            },
          ),
        );
      case WordReviewQuestionType.readingToWord:
        return Center(
          child: Text(
            item.reading ?? '',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        );
      case WordReviewQuestionType.wordToMeaning:
        // TODO: 如果需要注音，这里可以使用 RubyText
        return Center(
          child: Text(
            item.wordDetail.word.word,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
        );
    }
  }
}

class _OptionsArea extends StatelessWidget {
  final List<String> options;
  final bool hasMistake;
  final ValueChanged<String> onSelect;

  const _OptionsArea({
    required this.options,
    required this.hasMistake,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasMistake)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              '回答错误，请再试一次',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ...options.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => onSelect(opt),
              child: Text(
                opt,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingArea extends StatelessWidget {
  final WordReviewItem item;
  final ValueChanged<ReviewRating> onRate;

  const _RatingArea({required this.item, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 核心信息展示面板
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Text(
                item.wordDetail.word.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              if (item.reading != null && item.reading!.isNotEmpty)
                Text(
                  item.reading!,
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
              const SizedBox(height: 12),
              Text(
                item.meaning ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        const Text(
          '回想起来有多快？',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),

        // Hard / Good / Easy 按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RatingButton(
              label: 'Hard',
              color: Colors.red.shade400,
              onPressed: () => onRate(ReviewRating.hard),
            ),
            _RatingButton(
              label: 'Good',
              color: Colors.blue.shade400,
              onPressed: () => onRate(ReviewRating.good),
            ),
            _RatingButton(
              label: 'Easy',
              color: Colors.green.shade500,
              onPressed: () => onRate(ReviewRating.easy),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

String _titleForType(WordReviewQuestionType type, AppLocalizations l10n) {
  return switch (type) {
    WordReviewQuestionType.wordToMeaning => l10n.wordReviewTitleWordMeaning,
    WordReviewQuestionType.meaningToWord => l10n.wordReviewTitleMeaningWord,
    WordReviewQuestionType.audioToWord => l10n.wordReviewTitleAudioWord,
    WordReviewQuestionType.readingToWord => l10n.wordReviewTitleReadingWord,
  };
}
