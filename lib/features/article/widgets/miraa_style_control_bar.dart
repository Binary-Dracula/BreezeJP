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
            // 第一层：滑块与文本进度区
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildProgressArea(context, state, notifier, progress),
            ),

            // 第二层：5 个交互按钮区
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 12,
                left: 20,
                right: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. 恢复自动对齐（带脉冲动画）
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
                            : Colors.black26,
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

                  // 2. 显示模式轮转（翻译/假名切换）
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

                  // 3. 播放/暂停
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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

                  // 4. 倍速
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.toggleSpeed();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '${state.currentSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // 5. AB 循环切换开关
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: state.currentMode == ArticleMode.abLoop
                          ? Colors.blueAccent
                          : Colors.black26,
                      size: 24,
                    ),
                    tooltip: 'AB循环听',
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      notifier.setMode(
                        state.currentMode == ArticleMode.normal
                            ? ArticleMode.abLoop
                            : ArticleMode.normal,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建进度调节区（根据模式复用 Slider，确保尺寸统一防抖）
  Widget _buildProgressArea(
    BuildContext context,
    ArticleState state,
    ArticleAudioController notifier,
    double audioProgress,
  ) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              activeTrackColor: Colors.black87,
              inactiveTrackColor: Colors.black12,
              thumbColor: Colors.black,
              overlayColor: Colors.black.withValues(alpha: 0.08),
            ),
            child: state.currentMode == ArticleMode.normal
                ? Slider(
                    value: audioProgress,
                    onChangeStart: (_) {
                      setState(() => _isDragging = true);
                    },
                    onChanged: (value) {
                      setState(() => _dragProgress = value);
                    },
                    onChangeEnd: (value) {
                      HapticFeedback.selectionClick();
                      final targetMs = (value * state.article.durationMs)
                          .toInt();
                      notifier.seekToPosition(targetMs);
                      setState(() => _isDragging = false);
                    },
                  )
                : Slider(
                    value: state.targetLoopCount.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9, // 将 1-10 分成 9 段，使用户能直接吸附整数
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      notifier.setTargetLoopCount(value.toInt());
                    },
                  ),
          ),
        ),
        // 侧边文本框，使用 SizedBox 固定宽度，避免在 "01:23 / 03:45" 和 "1/3" 间切换时导致滑块变短或位移
        SizedBox(
          width: 85, // 增加宽度以防止 "00:00 / 00:00" 折行
          child: Text(
            state.currentMode == ArticleMode.normal
                ? _formatAudioTime(
                    state.currentPositionMs,
                    state.article.durationMs,
                  )
                : '${state.currentLoopCount}/${state.targetLoopCount}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontFeatures: [FontFeature.tabularFigures()], // 等宽数字
            ),
          ),
        ),
      ],
    );
  }

  /// 格式化音频时间 mm:ss / mm:ss
  String _formatAudioTime(int currentMs, int totalMs) {
    if (totalMs == 0) return "00:00 / 00:00";

    // 如果正在拖拽，使用拖拽的时间
    int displayMs = currentMs;
    if (_isDragging) {
      displayMs = (_dragProgress * totalMs).toInt();
    }

    String formatTime(int ms) {
      int totalSeconds = ms ~/ 1000;
      int minutes = totalSeconds ~/ 60;
      int seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${formatTime(displayMs)} / ${formatTime(totalMs)}';
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
