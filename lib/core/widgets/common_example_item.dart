import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'custom_ruby_text.dart';
import '../../features/learn/widgets/audio_play_button.dart';
import '../../services/audio_play_controller_provider.dart';
import '../../services/audio_play_controller.dart';
import '../../services/audio_play_state.dart';

/// 统一的例句数据接口，用于适配单词例句和语法例句
class ExampleDisplayData {
  final String japanese;
  final String? translation;
  final String? audioSource; // URL 或 文件名
  final String? ttsText; // 用于 TTS 播放的原始文本

  ExampleDisplayData({
    required this.japanese,
    this.translation,
    this.audioSource,
    this.ttsText,
  });
}

/// 通用的单条例句组件
class CommonExampleItem extends ConsumerWidget {
  final ExampleDisplayData data;
  final int order;
  final Color? primaryColor;

  const CommonExampleItem({
    super.key,
    required this.data,
    required this.order,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = primaryColor ?? theme.colorScheme.primary;

    final audioStatus = ref.watch(audioPlayControllerProvider);
    final audioController = ref.read(audioPlayControllerProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 序号 Badge
        _OrderBadge(order: order, color: color),
        const SizedBox(width: 12),
        // 内容区
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JapaneseSentence(
                text: data.japanese,
                fontSize: 18,
                rubyFontSize: 11,
              ),
              if (data.translation != null && data.translation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data.translation!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 播放按钮
        const SizedBox(width: 8),
        _buildPlayButton(audioStatus, audioController, color),
      ],
    );
  }

  Widget _buildPlayButton(
    AudioPlayStatus status,
    AudioPlayController controller,
    Color color,
  ) {
    // 优先使用音频源文件播放
    if (data.audioSource != null && data.audioSource!.isNotEmpty) {
      return AudioPlayButton(
        audioSource: data.audioSource!,
        size: 28,
        color: color,
      );
    }

    // 否则尝试 TTS
    if (data.ttsText != null && data.ttsText!.isNotEmpty) {
      final ttsSource = 'tts://${data.ttsText}';
      final isPlaying = status.isPlaying(ttsSource);
      final isLoading = status.isLoading(ttsSource);

      return IconButton(
        icon: isLoading
            ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(
                isPlaying ? Icons.stop_circle : Icons.play_circle,
                size: 28,
                color: color,
              ),
        onPressed: isLoading ? null : () => controller.toggleTts(data.ttsText!),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
    }

    return const SizedBox(width: 32);
  }
}

class _OrderBadge extends StatelessWidget {
  final int order;
  final Color color;

  const _OrderBadge({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        '$order',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
