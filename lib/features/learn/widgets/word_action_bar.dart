import 'package:flutter/material.dart';

import '../../../core/constants/learning_status.dart';

/// 单词学习页底部操作栏
/// 仅负责 UI 渲染与回调分发，不包含业务逻辑
class WordActionBar extends StatelessWidget {
  final LearningStatus userState;
  final VoidCallback onAddToReview;
  final VoidCallback onQuickMaster;
  final VoidCallback onMarkMastered;
  final VoidCallback onToggleIgnored;
  final VoidCallback onRestoreLearning;

  const WordActionBar({
    super.key,
    required this.userState,
    required this.onAddToReview,
    required this.onQuickMaster,
    required this.onMarkMastered,
    required this.onToggleIgnored,
    required this.onRestoreLearning,
  });

  @override
  Widget build(BuildContext context) {
    // 伪代码：
    // switch(userState):
    //   seen -> [加入复习, 一键掌握, 忽略]
    //   learning -> [已掌握, 忽略]
    //   ignored -> [恢复学习]
    //   mastered -> [恢复学习]
    final buttons = <Widget>[];

    if (userState == LearningStatus.seen) {
      buttons.addAll([
        _expandedButton(
          FilledButton(onPressed: onAddToReview, child: const Text('加入复习')),
        ),
        _expandedButton(
          OutlinedButton(onPressed: onQuickMaster, child: const Text('一键掌握')),
        ),
        _expandedButton(
          OutlinedButton(onPressed: onToggleIgnored, child: const Text('忽略')),
        ),
      ]);
    } else if (userState == LearningStatus.learning) {
      buttons.addAll([
        _expandedButton(
          FilledButton(onPressed: onMarkMastered, child: const Text('已掌握')),
        ),
        _expandedButton(
          OutlinedButton(onPressed: onToggleIgnored, child: const Text('忽略')),
        ),
      ]);
    } else if (userState == LearningStatus.ignored) {
      buttons.add(
        _expandedButton(
          FilledButton(onPressed: onToggleIgnored, child: const Text('恢复学习')),
        ),
      );
    } else if (userState == LearningStatus.mastered) {
      buttons.add(
        _expandedButton(
          FilledButton(onPressed: onRestoreLearning, child: const Text('恢复学习')),
        ),
      );
    }

    return SafeArea(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(children: _withGaps(buttons, gap: 8)),
      ),
    );
  }

  Widget _expandedButton(Widget child) {
    return Expanded(child: child);
  }

  List<Widget> _withGaps(List<Widget> children, {double gap = 8}) {
    if (children.length <= 1) return children;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(SizedBox(width: gap));
      }
      spaced.add(children[i]);
    }
    return spaced;
  }
}
