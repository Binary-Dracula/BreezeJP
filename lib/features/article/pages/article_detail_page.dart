import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// 黄金位置：高亮卡片的理想 leadingEdge（屏幕上方约 1/3 处）
  static const double _goldenAlignment = 0.3;

  /// 触发滚动的偏差阈值
  static const double _scrollThreshold = 0.08;

  /// 视口边界容差，避免浮点误差导致误判
  static const double _visibilityTolerance = 0.01;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleAudioProvider);

    // ── 统一滚动执行逻辑 ──────────────────────────────────
    void executeScroll(int targetIndex) {
      final currentState = ref.read(articleAudioProvider);
      final totalItems = currentState.article.items.length;
      if (totalItems == 0) return;

      // 播放完成重置：平滑回滚到页首
      if (targetIndex == -1) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            alignment: 0.0,
          );
        }
        return;
      }

      if (!_itemScrollController.isAttached) return;

      // 用户打断模式下不自动滚动
      if (currentState.userInterruptedScroll) return;

      final positions = _itemPositionsListener.itemPositions.value.toList();
      final lastIndex = totalItems - 1;
      if (targetIndex < 0 || targetIndex > lastIndex) return;

      // ── 收集视口中的关键位置信息 ──────────────────────
      ItemPosition? targetPos;
      ItemPosition? firstPos; // index == 0 的位置
      ItemPosition? lastPos; // index == lastIndex 的位置
      int? minVisibleIndex;
      int? maxVisibleIndex;

      for (var p in positions) {
        if (p.index == targetIndex) targetPos = p;
        if (p.index == 0) firstPos = p;
        if (p.index == lastIndex) lastPos = p;
        minVisibleIndex = minVisibleIndex == null
            ? p.index
            : (p.index < minVisibleIndex ? p.index : minVisibleIndex);
        maxVisibleIndex = maxVisibleIndex == null
            ? p.index
            : (p.index > maxVisibleIndex ? p.index : maxVisibleIndex);
      }

      final bool isFirstVisible =
          firstPos != null && firstPos.itemLeadingEdge >= -_visibilityTolerance;
      final bool isLastVisible =
          lastPos != null &&
          lastPos.itemTrailingEdge <= 1 + _visibilityTolerance;

      int viewportCenterIndex = targetIndex;
      if (minVisibleIndex != null && maxVisibleIndex != null) {
        viewportCenterIndex = ((minVisibleIndex + maxVisibleIndex) / 2).round();
      }
      final indexDelta = (targetIndex - viewportCenterIndex).abs();
      final durationMs = (380 + indexDelta * 35).clamp(380, 760).toInt();
      final scrollDuration = Duration(milliseconds: durationMs);

      // 首条：只回到顶部，不做向下调整
      if (targetIndex == 0) {
        if (!isFirstVisible) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: scrollDuration,
            curve: Curves.easeInOutCubic,
            alignment: 0.0,
          );
        }
        return;
      }

      // 末条：只滚到末尾，不再回拉到“黄金位”
      if (targetIndex == lastIndex) {
        if (!isLastVisible) {
          _itemScrollController.scrollTo(
            index: lastIndex,
            duration: scrollDuration,
            curve: Curves.easeInOutCubic,
            alignment: 1.0,
          );
        }
        return;
      }

      // ── 计算理想 alignment（黄金位置 0.3）──────────────
      const double idealAlignment = _goldenAlignment;

      // ── 基于视口实际位置，动态夹紧 alignment ───────────
      double safeAlignment = idealAlignment;
      bool shouldScroll = true;

      if (targetPos != null) {
        final currentLeading = targetPos.itemLeadingEdge;
        final currentTrailing = targetPos.itemTrailingEdge;
        final isFullyVisible =
            currentLeading >= -_visibilityTolerance &&
            currentTrailing <= 1 + _visibilityTolerance;
        double minSafeAlignment = 0.0;
        double maxSafeAlignment = 1.0;

        // 尾部安全夹紧：如果末项已在视口中，
        // 计算还能向上推多少而不超出自然滚动范围
        if (isLastVisible) {
          // 末项 trailing 到视口底部的剩余空间 = 可用的上推量
          final remainingSpace = (1.0 - lastPos.itemTrailingEdge)
              .clamp(0.0, 1.0)
              .toDouble();
          // 当前位置可达到的最小 alignment（最大上推）
          minSafeAlignment = currentLeading - remainingSpace;
        }

        // 头部安全夹紧：如果首项已在视口中，
        // 计算还能向下拉多少而不超出自然滚动范围
        if (isFirstVisible) {
          // 首项 leading 到视口顶部的剩余空间 = 可用的下拉量
          final topSpace = firstPos.itemLeadingEdge.clamp(0.0, 1.0).toDouble();
          // 当前位置可达到的最大 alignment（最大下拉）
          maxSafeAlignment = currentLeading + topSpace;
        }

        safeAlignment = idealAlignment
            .clamp(minSafeAlignment, maxSafeAlignment)
            .toDouble();
        final desiredShift = safeAlignment - currentLeading;
        shouldScroll =
            !isFullyVisible || desiredShift.abs() >= _scrollThreshold;
      }

      if (shouldScroll) {
        _itemScrollController.scrollTo(
          index: targetIndex,
          duration: scrollDuration,
          curve: Curves.easeInOutCubic,
          alignment: safeAlignment.clamp(0.0, 1.0).toDouble(),
        );
      }
    }

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
      executeScroll(next);
    });

    // 2. 用户取消打断 → 主动回归当前句子
    ref.listen<bool>(
      articleAudioProvider.select((s) => s.userInterruptedScroll),
      (previous, next) {
        if (previous == true && next == false) {
          executeScroll(ref.read(articleAudioProvider).activeIndex);
        }
      },
    );

    // ── 视图 ─────────────────────────────────────────
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        // 用户手动滑动：标记打断，停止自动滚动
        if (notification.direction != ScrollDirection.idle &&
            !state.userInterruptedScroll) {
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
}
