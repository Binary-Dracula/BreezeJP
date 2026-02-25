import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/article_text_item.dart';
import '../widgets/miraa_style_control_bar.dart';
import '../controller/article_audio_controller.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// ----------------------------------------------------------------------
// Article Detail Page
// ----------------------------------------------------------------------
class ArticleDetailPage extends ConsumerStatefulWidget {
  final String articleId;
  const ArticleDetailPage({super.key, required this.articleId});

  @override
  ConsumerState<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<ArticleDetailPage> {
  // 缓存 notifier 引用，确保 dispose 时仍可访问
  late final ArticleAudioController _audioController;

  @override
  void initState() {
    super.initState();
    _audioController = ref.read(articleAudioProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initArticle(widget.articleId);
    });
  }

  @override
  void dispose() {
    _audioController.disposeAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      // 使用 Column 布局：文章区域自然在工具栏之上，无重叠
      body: const Column(
        children: [
          // 文章滚动区域（Expanded 占满工具栏以上的全部空间）
          Expanded(child: _ArticleScrollView()),
          // 底部分割线
          Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          // 底部工具栏（固定在底部，不悬浮）
          MiraaStyleControlBar(),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 滚动视图组件
// ----------------------------------------------------------------------
class _ArticleScrollView extends ConsumerStatefulWidget {
  const _ArticleScrollView();

  @override
  ConsumerState<_ArticleScrollView> createState() => _ArticleScrollViewState();
}

class _ArticleScrollViewState extends ConsumerState<_ArticleScrollView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  _AutoScrollRequest? _pendingScrollRequest;
  bool _isAutoScrolling = false;
  bool _isDrainScheduled = false;

  /// 黄金位置：高亮卡片的理想 leadingEdge（屏幕上方约 1/3 处）
  static const double _goldenAlignment = 0.3;

  /// 触发滚动的偏差阈值
  static const double _scrollThreshold = 0.08;

  /// 恢复自动滚动时更积极回归阅读位
  static const double _resumeThreshold = 0.02;

  /// 视口边界容差，避免浮点误差导致误判
  static const double _visibilityTolerance = 0.01;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleAudioProvider);

    // ── 监听器 ────────────────────────────────────────
    // 1. activeIndex 变化 → 自动滚动 + 触感
    ref.listen<int>(articleAudioProvider.select((s) => s.activeIndex), (
      previous,
      next,
    ) {
      final currentState = ref.read(articleAudioProvider);
      if (previous != next &&
          next != -1 &&
          !currentState.userInterruptedScroll) {
        HapticFeedback.lightImpact();
      }
      _enqueueAutoScroll(_AutoScrollRequest(targetIndex: next));
    });

    // 2. 用户取消打断 → 主动回归当前句子
    ref.listen<bool>(
      articleAudioProvider.select((s) => s.userInterruptedScroll),
      (previous, next) {
        if (previous == true && next == false) {
          final currentIndex = ref.read(articleAudioProvider).activeIndex;
          if (currentIndex != -1) {
            _enqueueAutoScroll(
              _AutoScrollRequest(
                targetIndex: currentIndex,
                forceRecenter: true,
                isResume: true,
              ),
            );
          }
        }
      },
    );

    // ── 视图 ─────────────────────────────────────────
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 仅用户手势驱动的滚动才打断自动滚动
        if (_isUserDrivenScroll(notification) && !state.userInterruptedScroll) {
          ref
              .read(articleAudioProvider.notifier)
              .setUserInterruptedScroll(true);
        }
        return false;
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        physics: const ClampingScrollPhysics(), // 禁止 iOS 弹性回弹
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: 24.0, // 简单安全距离即可，工具栏已在布局之外
        ),
        itemCount: state.article.items.length,
        itemBuilder: (context, index) {
          final item = state.article.items[index];
          final isHighlight = state.activeIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ArticleTextItem(item: item, isHighlight: isHighlight),
          );
        },
      ),
    );
  }

  void _enqueueAutoScroll(_AutoScrollRequest request) {
    final pending = _pendingScrollRequest;
    if (pending == null) {
      _pendingScrollRequest = request;
    } else {
      _pendingScrollRequest = _AutoScrollRequest(
        targetIndex: request.targetIndex,
        forceRecenter: pending.forceRecenter || request.forceRecenter,
        isResume: pending.isResume || request.isResume,
      );
    }

    if (_isDrainScheduled) return;
    _isDrainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDrainScheduled = false;
      _drainAutoScrollQueue();
    });
  }

  void _drainAutoScrollQueue() {
    if (!mounted || _isAutoScrolling) return;

    final request = _pendingScrollRequest;
    _pendingScrollRequest = null;
    if (request == null) return;

    final currentState = ref.read(articleAudioProvider);
    if (currentState.userInterruptedScroll) {
      return;
    }

    final plan = _buildScrollPlan(request);
    if (plan == null) {
      if (_pendingScrollRequest != null) {
        _drainAutoScrollQueue();
      }
      return;
    }

    _performAutoScroll(plan);
  }

  _ScrollPlan? _buildScrollPlan(_AutoScrollRequest request) {
    if (!_itemScrollController.isAttached) return null;

    final state = ref.read(articleAudioProvider);
    final totalItems = state.article.items.length;
    if (totalItems == 0) return null;

    final lastIndex = totalItems - 1;
    if (request.targetIndex < -1 || request.targetIndex > lastIndex) {
      return null;
    }

    final positions = _itemPositionsListener.itemPositions.value.toList();

    ItemPosition? targetPos;
    ItemPosition? firstPos;
    ItemPosition? lastPos;
    int? minVisibleIndex;
    int? maxVisibleIndex;

    for (final p in positions) {
      if (p.index == request.targetIndex) targetPos = p;
      if (p.index == 0) firstPos = p;
      if (p.index == lastIndex) lastPos = p;
      minVisibleIndex = minVisibleIndex == null
          ? p.index
          : (p.index < minVisibleIndex ? p.index : minVisibleIndex);
      maxVisibleIndex = maxVisibleIndex == null
          ? p.index
          : (p.index > maxVisibleIndex ? p.index : maxVisibleIndex);
    }

    final bool isFirstAtTop =
        firstPos != null && firstPos.itemLeadingEdge >= -_visibilityTolerance;
    final bool isLastAtBottom =
        lastPos != null && lastPos.itemTrailingEdge <= 1 + _visibilityTolerance;

    // activeIndex = -1 表示播放完成，自动模式下平滑回到顶部
    if (request.targetIndex == -1) {
      if (state.userInterruptedScroll || isFirstAtTop) return null;
      return _ScrollPlan(
        index: 0,
        alignment: 0.0,
        duration: _scrollDuration(
          targetIndex: 0,
          minVisibleIndex: minVisibleIndex,
          maxVisibleIndex: maxVisibleIndex,
          isResume: request.isResume,
        ),
      );
    }

    // 首条：只允许向上归位，不为了黄金位向下拉
    if (request.targetIndex == 0) {
      if (isFirstAtTop) return null;
      return _ScrollPlan(
        index: 0,
        alignment: 0.0,
        duration: _scrollDuration(
          targetIndex: 0,
          minVisibleIndex: minVisibleIndex,
          maxVisibleIndex: maxVisibleIndex,
          isResume: request.isResume,
        ),
      );
    }

    // 末条：只允许滚到底，不再回拉
    if (request.targetIndex == lastIndex) {
      if (isLastAtBottom) return null;
      return _ScrollPlan(
        index: lastIndex,
        alignment: 1.0,
        duration: _scrollDuration(
          targetIndex: lastIndex,
          minVisibleIndex: minVisibleIndex,
          maxVisibleIndex: maxVisibleIndex,
          isResume: request.isResume,
        ),
      );
    }

    final idealAlignment = _idealAlignmentFor(request.targetIndex);

    // 目标不在视口，直接按理想位滚入
    if (targetPos == null) {
      return _ScrollPlan(
        index: request.targetIndex,
        alignment: idealAlignment,
        duration: _scrollDuration(
          targetIndex: request.targetIndex,
          minVisibleIndex: minVisibleIndex,
          maxVisibleIndex: maxVisibleIndex,
          isResume: request.isResume,
        ),
      );
    }

    final currentLeading = targetPos.itemLeadingEdge;
    final currentTrailing = targetPos.itemTrailingEdge;
    final isFullyVisible =
        currentLeading >= -_visibilityTolerance &&
        currentTrailing <= 1 + _visibilityTolerance;

    double minSafeAlignment = 0.0;
    double maxSafeAlignment = 1.0;

    if (isLastAtBottom) {
      final remainingBottomSpace = (1.0 - lastPos.itemTrailingEdge)
          .clamp(0.0, 1.0)
          .toDouble();
      minSafeAlignment = currentLeading - remainingBottomSpace;
    }

    if (isFirstAtTop) {
      final topSpace = firstPos.itemLeadingEdge.clamp(0.0, 1.0).toDouble();
      maxSafeAlignment = currentLeading + topSpace;
    }

    final safeAlignment = idealAlignment
        .clamp(minSafeAlignment, maxSafeAlignment)
        .toDouble();
    final desiredShift = safeAlignment - currentLeading;
    final threshold = request.forceRecenter
        ? _resumeThreshold
        : _scrollThreshold;
    final shouldScroll = !isFullyVisible || desiredShift.abs() >= threshold;

    if (!shouldScroll) return null;

    return _ScrollPlan(
      index: request.targetIndex,
      alignment: safeAlignment,
      duration: _scrollDuration(
        targetIndex: request.targetIndex,
        minVisibleIndex: minVisibleIndex,
        maxVisibleIndex: maxVisibleIndex,
        isResume: request.isResume,
      ),
    );
  }

  Duration _scrollDuration({
    required int targetIndex,
    required int? minVisibleIndex,
    required int? maxVisibleIndex,
    required bool isResume,
  }) {
    int viewportCenterIndex = targetIndex;
    if (minVisibleIndex != null && maxVisibleIndex != null) {
      viewportCenterIndex = ((minVisibleIndex + maxVisibleIndex) / 2).round();
    }

    final indexDelta = (targetIndex - viewportCenterIndex).abs();
    final base = isResume ? 460 : 360;
    final perIndex = isResume ? 42 : 32;
    final maxDuration = isResume ? 920 : 760;
    final durationMs = (base + indexDelta * perIndex).clamp(base, maxDuration);
    return Duration(milliseconds: durationMs.toInt());
  }

  double _idealAlignmentFor(int targetIndex) {
    if (targetIndex <= 2) {
      final alignment = 0.08 + (targetIndex * 0.08);
      return alignment.clamp(0.0, _goldenAlignment).toDouble();
    }
    return _goldenAlignment;
  }

  Future<void> _performAutoScroll(_ScrollPlan plan) async {
    if (!mounted || !_itemScrollController.isAttached) return;

    _isAutoScrolling = true;
    try {
      await _itemScrollController.scrollTo(
        index: plan.index,
        duration: plan.duration,
        curve: Curves.easeInOutCubic,
        alignment: plan.alignment,
      );
    } catch (_) {
      // 列表重建或页面销毁时，scrollTo 可能中断
    } finally {
      _isAutoScrolling = false;
      if (mounted && _pendingScrollRequest != null) {
        _drainAutoScrollQueue();
      }
    }
  }

  bool _isUserDrivenScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      return notification.dragDetails != null;
    }
    if (notification is ScrollUpdateNotification) {
      return notification.dragDetails != null;
    }
    if (notification is OverscrollNotification) {
      return notification.dragDetails != null;
    }
    return false;
  }
}

class _AutoScrollRequest {
  final int targetIndex;
  final bool forceRecenter;
  final bool isResume;

  const _AutoScrollRequest({
    required this.targetIndex,
    this.forceRecenter = false,
    this.isResume = false,
  });
}

class _ScrollPlan {
  final int index;
  final double alignment;
  final Duration duration;

  const _ScrollPlan({
    required this.index,
    required this.alignment,
    required this.duration,
  });
}
