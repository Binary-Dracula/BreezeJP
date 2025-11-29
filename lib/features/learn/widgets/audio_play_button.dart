import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audio_play_controller_provider.dart';

/// 音频播放按钮组件
/// 基于 AudioPlayController 状态机自动响应状态变化
class AudioPlayButton extends ConsumerWidget {
  final String? audioSource;
  final double size;
  final Color? color;

  const AudioPlayButton({
    super.key,
    required this.audioSource,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (audioSource == null || audioSource!.isEmpty) {
      return const SizedBox.shrink();
    }

    final audioStatus = ref.watch(audioPlayControllerProvider);
    final controller = ref.read(audioPlayControllerProvider.notifier);
    final theme = Theme.of(context);

    final isThisPlaying = audioStatus.isPlaying(audioSource!);
    final isThisLoading = audioStatus.isLoading(audioSource!);
    final iconColor = color ?? theme.colorScheme.primary;

    return IconButton(
      icon: _buildIcon(isThisPlaying, isThisLoading, iconColor),
      onPressed: isThisLoading ? null : () => controller.toggle(audioSource!),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
    );
  }

  Widget _buildIcon(bool isPlaying, bool isLoading, Color iconColor) {
    if (isLoading) {
      return SizedBox(
        width: size * 0.8,
        height: size * 0.8,
        child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
      );
    }

    return Icon(
      isPlaying ? Icons.stop_circle : Icons.play_circle,
      size: size,
      color: iconColor,
    );
  }
}
