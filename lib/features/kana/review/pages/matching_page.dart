import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/tracking/page_duration_tracking_mixin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/audio_service_provider.dart';
import '../controller/matching_controller.dart';
import '../state/review_kana_item.dart';
import '../state/matching_state.dart';

const double _kOptionHeight = 80;
const double _kOptionGap = 16;

class MatchingPage extends ConsumerStatefulWidget {
  const MatchingPage({super.key});

  @override
  ConsumerState<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends ConsumerState<MatchingPage>
    with PageDurationTrackingMixin<MatchingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchingControllerProvider.notifier).loadReview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(matchingControllerProvider);
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
          appBar: AppBar(title: const Text('五十音复习')),
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
                            .read(matchingControllerProvider.notifier)
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
          appBar: AppBar(title: const Text('五十音复习')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('暂无待复习五十音', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    /// 全部复习完成
    if (state.isAllFinished) {
      return WillPopScope(
        onWillPop: _handlePop,
        child: Scaffold(
          appBar: AppBar(title: const Text('五十音复习')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('今日五十音复习已完成', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(matchingControllerProvider.notifier)
                        .endSession();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('返回'),
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
          appBar: AppBar(title: const Text('五十音复习')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => ref
                      .read(matchingControllerProvider.notifier)
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
          title: Text(_titleForType(questionType)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),

            /// 题型指示
            Text(
              _subtitleForType(questionType),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Row(
                children: [
                  /// 左侧题目列
                  Expanded(
                    child: _LeftColumn(
                      state: state,
                      ref: ref,
                      onTap: (index) {
                        ref
                            .read(matchingControllerProvider.notifier)
                            .selectLeft(index);
                      },
                    ),
                  ),

                  /// 右侧答案列
                  Expanded(
                    child: _RightColumn(
                      state: state,
                      options: options,
                      onTap: (index) {
                        ref
                            .read(matchingControllerProvider.notifier)
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
    await ref.read(matchingControllerProvider.notifier).endSession();
    return true;
  }
}

class _LeftColumn extends StatelessWidget {
  final MatchingState state;
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
                  'left-${item.kanaLetter.id}'
                  '-${item.questionType.name}',
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
                          if (item.questionType == ReviewQuestionType.audio) {
                            final raw = item.audioFilename ?? '';
                            if (raw.trim().isNotEmpty) {
                              ref
                                  .read(audioServiceProvider)
                                  .playAudio(_normalizeKanaAudioPath(raw));
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
                      child: item.questionType == ReviewQuestionType.audio
                          ? const Icon(Icons.volume_up, size: 28)
                          : Text(
                              pair.left,
                              style: const TextStyle(fontSize: 24),
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
  final MatchingState state;
  final List<RightOption> options;
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
                        style: const TextStyle(fontSize: 20),
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

String _titleForType(ReviewQuestionType type) {
  return switch (type) {
    ReviewQuestionType.recall => '读音回忆（配对）',
    ReviewQuestionType.audio => '听音辨假名（配对）',
    ReviewQuestionType.switchMode => '平假名 ↔ 片假名 配对',
  };
}

String _subtitleForType(ReviewQuestionType type) {
  return switch (type) {
    ReviewQuestionType.recall => '点击假名 → 点击正确罗马音',
    ReviewQuestionType.audio => '点击音频 → 点击对应假名',
    ReviewQuestionType.switchMode => '将平假名与对应片假名配对',
  };
}

String _normalizeKanaAudioPath(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;

  if (v.startsWith('assets/')) return v;

  if (v.endsWith('.mp3') || v.endsWith('.wav') || v.endsWith('.m4a')) {
    return 'assets/audio/kana/$v';
  }

  return 'assets/audio/kana/$v.mp3';
}
