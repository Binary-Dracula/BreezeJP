import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tracking/page_duration_tracking_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_service_provider.dart';
import '../controller/word_review_controller.dart';
import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

const double _kOptionHeight = 80;
const double _kOptionGap = 16;

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
    final options = state.rightOptions;

    if (state.isLoading) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.error != null) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
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
        ),
      );
    }

    if (state.isEmpty) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(l10n.wordReviewEmpty, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    if (state.isAllFinished) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.wordReviewFinished, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(wordReviewControllerProvider.notifier).endSession();
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

    final questionType = state.currentQuestionType;
    if (questionType == null) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.wordReviewTitle)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
      );
    }

    return WillPopScope(
      onWillPop: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleForType(questionType, l10n)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              _subtitleForType(questionType, l10n),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _LeftColumn(
                      state: state,
                      ref: ref,
                      onTap: (index) {
                        ref
                            .read(wordReviewControllerProvider.notifier)
                            .selectLeft(index);
                      },
                    ),
                  ),
                  Expanded(
                    child: _RightColumn(
                      state: state,
                      options: options,
                      onTap: (index) {
                        ref
                            .read(wordReviewControllerProvider.notifier)
                            .selectRight(index);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<bool> _handlePop() async {
    await ref.read(wordReviewControllerProvider.notifier).endSession();
    return true;
  }
}

class _LeftColumn extends StatelessWidget {
  final WordReviewState state;
  final WidgetRef ref;
  final void Function(int index) onTap;

  const _LeftColumn({
    required this.state,
    required this.ref,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = state.activePairs;
    if (pairs.isEmpty) return const SizedBox.shrink();

    final selectedLeftIndex = state.selectedLeftIndex;
    final selectedRightIndex = state.selectedRightIndex;
    final hasBothSelected =
        selectedLeftIndex != null && selectedRightIndex != null;
    final isCorrect =
        selectedLeftIndex != null &&
        selectedRightIndex != null &&
        selectedRightIndex >= 0 &&
        selectedRightIndex < state.rightOptions.length &&
        selectedLeftIndex == state.rightOptions[selectedRightIndex].pairIndex;

    final children = <Widget>[];
    for (var index = 0; index < pairs.length; index++) {
      if (index > 0) {
        children.add(const SizedBox(height: _kOptionGap));
      }
      final pair = pairs[index];
      final item = pair.item;
      final isMatched = pair.isMatched;
      final isSelected = selectedLeftIndex == index;
      final isFailure = hasBothSelected && !isCorrect && isSelected;
      final isCorrectSelected = hasBothSelected && isCorrect && isSelected;

      final bgColor = isMatched
          ? Colors.green.shade200
          : isCorrectSelected
              ? Colors.green.shade200
              : isFailure
                  ? Colors.red.shade200
                  : isSelected
                      ? Colors.blue.shade100
                      : Colors.grey.shade200;

      children.add(
        SizedBox(
          height: _kOptionHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(
                  'left-${item.studyWord.wordId}-${item.questionType.name}',
                ),
                tween: Tween<double>(begin: 0, end: isFailure ? 1 : 0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  final dx = isFailure
                      ? math.sin(value * math.pi * 6) * 6
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: isMatched
                      ? null
                      : () {
                          onTap(index);
                          if (item.questionType ==
                              WordReviewQuestionType.audioToWord) {
                            final source = item.audioSource ?? '';
                            if (source.trim().isNotEmpty) {
                              ref.read(audioServiceProvider).playAudio(source);
                            }
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMatched
                            ? Colors.green
                            : isSelected
                                ? Colors.blueAccent
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: item.questionType ==
                              WordReviewQuestionType.audioToWord
                          ? const Icon(Icons.volume_up, size: 28)
                          : Text(
                              pair.left,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight =
            pairs.length * _kOptionHeight +
                (pairs.length > 1 ? (pairs.length - 1) * _kOptionGap : 0);
        final shouldCenter = contentHeight <= constraints.maxHeight;

        return SingleChildScrollView(
          physics: shouldCenter ? const NeverScrollableScrollPhysics() : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: shouldCenter
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _RightColumn extends StatelessWidget {
  final WordReviewState state;
  final List<WordReviewOption> options;
  final void Function(int index) onTap;

  const _RightColumn({
    required this.state,
    required this.options,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final selectedLeftIndex = state.selectedLeftIndex;
    final selectedRightIndex = state.selectedRightIndex;
    final hasBothSelected =
        selectedLeftIndex != null && selectedRightIndex != null;
    final isCorrect =
        selectedLeftIndex != null &&
        selectedRightIndex != null &&
        selectedRightIndex >= 0 &&
        selectedRightIndex < state.rightOptions.length &&
        selectedLeftIndex == state.rightOptions[selectedRightIndex].pairIndex;

    final children = <Widget>[];
    for (var index = 0; index < options.length; index++) {
      if (index > 0) {
        children.add(const SizedBox(height: _kOptionGap));
      }
      final option = options[index];
      final pairIndex = option.pairIndex;
      final isMatched =
          pairIndex >= 0 &&
          pairIndex < state.activePairs.length &&
          state.activePairs[pairIndex].isMatched;
      final isSelected = selectedRightIndex == index;
      final isFailure = hasBothSelected && !isCorrect && isSelected;
      final isCorrectSelected = hasBothSelected && isCorrect && isSelected;

      final bgColor = isMatched
          ? Colors.green.shade200
          : isCorrectSelected
              ? Colors.green.shade200
              : isFailure
                  ? Colors.red.shade200
                  : isSelected
                      ? Colors.blue.shade100
                      : Colors.grey.shade200;

      children.add(
        SizedBox(
          height: _kOptionHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('right-${option.value}-$pairIndex'),
                tween: Tween<double>(begin: 0, end: isFailure ? 1 : 0),
                duration: const Duration(milliseconds: 260),
                builder: (context, val, child) {
                  final dx = isFailure ? math.sin(val * math.pi * 6) * 5 : 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: isMatched ? null : () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMatched
                            ? Colors.green
                            : isCorrectSelected
                                ? Colors.green
                                : isFailure
                                    ? Colors.red
                                    : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        option.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight =
            options.length * _kOptionHeight +
                (options.length > 1 ? (options.length - 1) * _kOptionGap : 0);
        final shouldCenter = contentHeight <= constraints.maxHeight;

        return SingleChildScrollView(
          physics: shouldCenter ? const NeverScrollableScrollPhysics() : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: shouldCenter
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

String _titleForType(
  WordReviewQuestionType type,
  AppLocalizations l10n,
) {
  return switch (type) {
    WordReviewQuestionType.wordToMeaning => l10n.wordReviewTitleWordMeaning,
    WordReviewQuestionType.meaningToWord => l10n.wordReviewTitleMeaningWord,
    WordReviewQuestionType.audioToWord => l10n.wordReviewTitleAudioWord,
    WordReviewQuestionType.readingToWord => l10n.wordReviewTitleReadingWord,
  };
}

String _subtitleForType(
  WordReviewQuestionType type,
  AppLocalizations l10n,
) {
  return switch (type) {
    WordReviewQuestionType.wordToMeaning =>
        l10n.wordReviewSubtitleWordMeaning,
    WordReviewQuestionType.meaningToWord =>
        l10n.wordReviewSubtitleMeaningWord,
    WordReviewQuestionType.audioToWord => l10n.wordReviewSubtitleAudioWord,
    WordReviewQuestionType.readingToWord => l10n.wordReviewSubtitleReadingWord,
  };
}
