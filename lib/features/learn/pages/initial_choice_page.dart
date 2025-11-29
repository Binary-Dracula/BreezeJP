import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/initial_choice_controller.dart';
import '../state/initial_choice_state.dart';
import '../widgets/word_choice_card.dart';

/// 初始选择页
/// 展示 5 个随机单词供用户选择学习起点
class InitialChoicePage extends ConsumerStatefulWidget {
  const InitialChoicePage({super.key});

  @override
  ConsumerState<InitialChoicePage> createState() => _InitialChoicePageState();
}

class _InitialChoicePageState extends ConsumerState<InitialChoicePage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时获取随机单词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(initialChoiceControllerProvider.notifier).loadChoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(initialChoiceControllerProvider);
    final controller = ref.read(initialChoiceControllerProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部操作栏
              _buildTopActions(context, state, controller),
              const SizedBox(height: 24),
              // 页面标题
              Text(
                l10n.initialChoiceTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.initialChoiceSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              // 单词选择网格
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部操作栏
  Widget _buildTopActions(
    BuildContext context,
    InitialChoiceState state,
    InitialChoiceController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 返回按钮
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        // 刷新按钮
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: state.isLoading ? null : controller.refresh,
        ),
      ],
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, InitialChoiceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(initialChoiceControllerProvider.notifier).refresh();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.choices.isEmpty) {
      return const Center(child: Text('没有可学习的单词'));
    }

    return ListView.separated(
      itemCount: state.choices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final wordChoice = state.choices[index];
        return WordChoiceCard(
          wordChoice: wordChoice,
          onTap: () => context.push('/learn/${wordChoice.word.id}'),
        );
      },
    );
  }
}
