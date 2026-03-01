import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/article_audio_controller.dart';
import '../state/article_state.dart';
import 'package:flutter/services.dart';

/// 底部工具栏（精简版：进度条 + 核心控制按钮）
class MiraaStyleControlBar extends ConsumerStatefulWidget {
  const MiraaStyleControlBar({super.key});

  @override
  ConsumerState<MiraaStyleControlBar> createState() =>
      _MiraaStyleControlBarState();
}

class _MiraaStyleControlBarState extends ConsumerState<MiraaStyleControlBar>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  // 定位按钮脉冲动画
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleAudioProvider);
    final notifier = ref.read(articleAudioProvider.notifier);

    // 脉冲动画控制
    if (state.userInterruptedScroll) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    // 进度条值
    double progress = 0.0;
    if (_isDragging) {
      progress = _dragProgress;
    } else {
      if (state.article.durationMs > 0) {
        progress = state.currentPositionMs / state.article.durationMs;
        progress = progress.clamp(0.0, 1.0);
      }
    }

    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFFDFBF7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14.0,
                  ),
                  activeTrackColor: Colors.black87,
                  inactiveTrackColor: Colors.black12,
                  thumbColor: Colors.black,
                  overlayColor: Colors.black.withValues(alpha: 0.08),
                ),
                child: Slider(
                  value: progress,
                  onChangeStart: (_) {
                    setState(() => _isDragging = true);
                  },
                  onChanged: (value) {
                    setState(() => _dragProgress = value);
                  },
                  onChangeEnd: (value) {
                    HapticFeedback.selectionClick();
                    final targetMs = (value * state.article.durationMs).toInt();
                    notifier.seekToPosition(targetMs);
                    setState(() => _isDragging = false);
                  },
                ),
              ),
            ),
            // 操控按钮行
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 恢复自动对齐（带脉冲动画）
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: state.userInterruptedScroll
                            ? _pulseAnimation.value
                            : 1.0,
                        child: child,
                      );
                    },
                    child: IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: state.userInterruptedScroll
                            ? Colors.blueAccent
                            : Colors.black12,
                        size: 24,
                      ),
                      tooltip: '回到当前',
                      onPressed: state.userInterruptedScroll
                          ? () {
                              HapticFeedback.mediumImpact();
                              notifier.setUserInterruptedScroll(false);
                            }
                          : null,
                    ),
                  ),

                  // 显示模式轮转（假名+翻译 / 仅假名 / 仅翻译）
                  IconButton(
                    icon: Icon(
                      _displayModeIcon(state.displayMode),
                      color: Colors.black87,
                      size: 24,
                    ),
                    tooltip: _displayModeTooltip(state.displayMode),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.toggleDisplayMode();
                    },
                  ),

                  // 倍速
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.toggleSpeed();
                    },
                    child: Text(
                      '${state.currentSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // 播放/暂停
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.togglePlayPause();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据当前显示模式返回对应图标
  IconData _displayModeIcon(ArticleDisplayMode mode) {
    return switch (mode) {
      ArticleDisplayMode.all => Icons.visibility,
      ArticleDisplayMode.furiganaOnly => Icons.translate,
      ArticleDisplayMode.translationOnly => Icons.subtitles,
      ArticleDisplayMode.none => Icons.visibility_off,
    };
  }

  /// 根据当前显示模式返回对应提示文本
  String _displayModeTooltip(ArticleDisplayMode mode) {
    return switch (mode) {
      ArticleDisplayMode.all => '假名+翻译',
      ArticleDisplayMode.furiganaOnly => '仅假名',
      ArticleDisplayMode.translationOnly => '仅翻译',
      ArticleDisplayMode.none => '全部隐藏',
    };
  }
}
