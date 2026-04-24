import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/algorithm/srs_types.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../data/queries/book_query_provider.dart';
import '../../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentAlgorithm = ref.watch(algorithmTypeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);
    final selectedBookAsync = ref.watch(selectedBookProvider);
    final email = currentUser?.email ?? '';
    final isLoggedIn = currentUser != null;

    final initials = isLoggedIn
        ? ((displayName?.isNotEmpty == true)
              ? displayName![0].toUpperCase()
              : (email.isNotEmpty ? email[0].toUpperCase() : '?'))
        : '?';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 账号区域 ──
              const Text(
                '账号',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: GestureDetector(
                  onTap: isLoggedIn
                      ? () => context.push('/settings/profile')
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn
                                  ? (displayName ?? currentUser.email ?? '已登录')
                                  : '游客模式',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLoggedIn ? '查看个人资料' : '登录后可使用云端功能',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoggedIn)
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        )
                      else
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('前往登录'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '系统偏好',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/book-selection/settings'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5C8DFF),
                                      Color(0xFF6DD5ED),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.settingsCurrentBook,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedBookAsync.when(
                                        data: (book) =>
                                            book?.title ??
                                            l10n.settingsNoSelectedBook,
                                        loading: () => l10n.loading,
                                        error: (_, _) =>
                                            l10n.settingsNoSelectedBook,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '记忆算法',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '选择驱动间隔重复的底层模型',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AlgorithmType>(
                        segments: const [
                          ButtonSegment<AlgorithmType>(
                            value: AlgorithmType.sm2,
                            label: Text('SM-2'),
                            icon: Icon(Icons.history_edu),
                          ),
                          ButtonSegment<AlgorithmType>(
                            value: AlgorithmType.fsrs,
                            label: Text('FSRS v4'),
                            icon: Icon(Icons.bolt),
                          ),
                        ],
                        selected: <AlgorithmType>{currentAlgorithm},
                        onSelectionChanged: (Set<AlgorithmType> newSelection) {
                          ref
                              .read(algorithmTypeProvider.notifier)
                              .setType(newSelection.first);
                        },
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '首次复习时间安排',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '新学单词多久后进行初次检测',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final interval = ref.watch(firstReviewIntervalProvider);
                        final sliderValue = interval.clamp(10, 50).toDouble();

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFF10B981),
                                inactiveTrackColor: Colors.grey.shade200,
                                thumbColor: const Color(0xFF10B981),
                                overlayColor: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.12),
                                valueIndicatorColor: const Color(0xFF10B981),
                                showValueIndicator: ShowValueIndicator.onDrag,
                              ),
                              child: Slider(
                                value: sliderValue,
                                min: 10,
                                max: 50,
                                divisions: 8,
                                label: '${sliderValue.round()} 分钟',
                                onChanged: (value) {
                                  ref
                                      .read(
                                        firstReviewIntervalProvider.notifier,
                                      )
                                      .setInterval(value.round());
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '10 分钟',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    '当前: ${sliderValue.round()} 分钟',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    '50 分钟',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // ── 每次学习单词数 ──
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5C8DFF), Color(0xFF6DD5ED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.format_list_numbered_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '每次学习单词数',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '每次从辞书中拉取的新词数量',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final batchSize = ref.watch(learnBatchSizeProvider);
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFF5C8DFF),
                                inactiveTrackColor: Colors.grey.shade200,
                                thumbColor: const Color(0xFF5C8DFF),
                                overlayColor: const Color(
                                  0xFF5C8DFF,
                                ).withValues(alpha: 0.12),
                                valueIndicatorColor: const Color(0xFF5C8DFF),
                                showValueIndicator: ShowValueIndicator.onDrag,
                              ),
                              child: Slider(
                                value: batchSize.toDouble(),
                                min: 10,
                                max: 50,
                                divisions: 8,
                                label: '$batchSize 词',
                                onChanged: (value) {
                                  ref
                                      .read(learnBatchSizeProvider.notifier)
                                      .setSize(value.round());
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '10',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    '当前: $batchSize 词',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5C8DFF),
                                    ),
                                  ),
                                  Text(
                                    '50',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
