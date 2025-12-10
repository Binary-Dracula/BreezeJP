import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/audio_service_provider.dart';
import '../controller/matching_controller.dart';
import '../state/kana_review_state.dart';
import '../state/matching_pair.dart';
import '../state/matching_state.dart';

class MatchingPage extends ConsumerStatefulWidget {
  const MatchingPage({super.key});

  @override
  ConsumerState<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends ConsumerState<MatchingPage> {
  int? _pendingRightIndex;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchingControllerProvider);
    final options = _buildUniqueOptions(state.activePairs);
    final pendingRightIndex =
        (_pendingRightIndex != null &&
            _pendingRightIndex! >= 0 &&
            _pendingRightIndex! < options.length)
        ? _pendingRightIndex
        : null;

    /// 全部复习完成
    if (state.isAllFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('五十音复习')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('今日五十音复习已完成', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    /// 当前组加载中
    if (state.isLoading || state.currentQuestionType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titleForType(state.currentQuestionType!))),

      body: Column(
        children: [
          const SizedBox(height: 12),

          /// 题型指示
          Text(
            _subtitleForType(state.currentQuestionType!),
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
                    options: options,
                    pendingRightIndex: pendingRightIndex,
                    onTap: (index) {
                      _handleLeftTap(index, options);
                    },
                  ),
                ),

                /// 右侧答案列
                Expanded(
                  child: _RightColumn(
                    state: state,
                    pendingRightIndex: pendingRightIndex,
                    options: options,
                    onTap: (index) {
                      _handleRightTap(index, state, options);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// 底部按钮区域（用于显示组完成 / 下一组）
          _BottomArea(state: state, ref: ref),
        ],
      ),
    );
  }

  void _handleLeftTap(int index, List<String> options) {
    ref.read(matchingControllerProvider.notifier).selectLeft(index);
    final pending =
        (_pendingRightIndex != null &&
            _pendingRightIndex! >= 0 &&
            _pendingRightIndex! < options.length)
        ? _pendingRightIndex
        : null;
    if (pending != null) {
      setState(() {
        _pendingRightIndex = null;
      });
      ref.read(matchingControllerProvider.notifier).selectRight(pending);
    }
  }

  void _handleRightTap(int index, MatchingState state, List<String> options) {
    final hasLeftSelected = state.selectedLeftIndex != null;
    if (hasLeftSelected) {
      setState(() {
        _pendingRightIndex = null;
      });
      ref.read(matchingControllerProvider.notifier).selectRight(index);
    } else {
      setState(() {
        _pendingRightIndex = index;
      });
    }
  }
}

class _LeftColumn extends StatelessWidget {
  final MatchingState state;
  final WidgetRef ref;
  final List<String> options;
  final int? pendingRightIndex;
  final void Function(int index) onTap;

  const _LeftColumn({
    required this.state,
    required this.ref,
    required this.options,
    required this.pendingRightIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = state.activePairs;
    final selectedRight = state.selectedRightIndex ?? pendingRightIndex;
    final selectedOption =
        (selectedRight != null &&
            selectedRight >= 0 &&
            selectedRight < options.length)
        ? options[selectedRight]
        : null;

    return ListView.builder(
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final selected = state.selectedLeftIndex == index;
        final isFailure =
            selected &&
            selectedOption != null &&
            selectedOption != pair.rightCorrect;
        final bgColor = isFailure
            ? Colors.red.shade100
            : selected
            ? Colors.blue.shade100
            : Colors.grey.shade200;

        return AnimatedSwitcher(
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
              'left-${pair.item.kanaLetter.id}'
              '-${pair.item.questionType.name}',
            ),
            tween: Tween<double>(begin: 0, end: isFailure ? 1 : 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              final dx = isFailure ? math.sin(value * math.pi * 6) * 6 : 0.0;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: GestureDetector(
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.blueAccent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: pair.item.questionType == ReviewQuestionType.audio
                      ? IconButton.filled(
                          iconSize: 28,
                          onPressed: pair.left.isEmpty
                              ? null
                              : () => ref
                                    .read(audioServiceProvider)
                                    .playAudio(pair.left),
                          icon: const Icon(Icons.volume_up),
                        )
                      : Text(pair.left, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RightColumn extends StatelessWidget {
  final MatchingState state;
  final int? pendingRightIndex;
  final List<String> options;
  final void Function(int index) onTap;

  const _RightColumn({
    required this.state,
    required this.pendingRightIndex,
    required this.options,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLeft = state.selectedLeftIndex;
    final selectedPair =
        (selectedLeft != null &&
            selectedLeft >= 0 &&
            selectedLeft < state.activePairs.length)
        ? state.activePairs[selectedLeft]
        : null;
    final selectedRight = state.selectedRightIndex ?? pendingRightIndex;

    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (context, index) {
        final value = options[index];
        final selected = selectedRight == index;
        final isFailure =
            selected &&
            selectedPair != null &&
            selectedPair.rightCorrect != value;
        final isCorrect =
            selected &&
            selectedPair != null &&
            selectedPair.rightCorrect == value;
        final bgColor = isCorrect
            ? Colors.green.shade200
            : isFailure
            ? Colors.red.shade200
            : selected
            ? Colors.green.shade100
            : Colors.grey.shade200;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('right-$value'),
            tween: Tween<double>(begin: 0, end: isFailure ? 1 : 0),
            duration: const Duration(milliseconds: 260),
            builder: (context, val, child) {
              final dx = isFailure ? math.sin(val * math.pi * 6) * 5 : 0.0;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: GestureDetector(
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : isFailure
                        ? Colors.red
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(value, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomArea extends StatelessWidget {
  final MatchingState state;
  final WidgetRef ref;

  const _BottomArea({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (state.isGroupFinished && !state.isAllFinished) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            ref.read(matchingControllerProvider.notifier).startNextGroup();
          },
          child: const Text('进入下一组'),
        ),
      );
    }

    return const SizedBox(height: 24);
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

List<String> _buildUniqueOptions(List<MatchingPair> pairs) {
  final options = <String>[];
  final seen = <String>{};
  for (final pair in pairs) {
    for (final option in pair.rightOptions) {
      if (seen.add(option)) {
        options.add(option);
      }
    }
  }
  return options;
}
