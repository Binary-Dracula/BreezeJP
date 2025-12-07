import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../controller/home_controller.dart';
import '../state/home_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider.notifier).loadHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading && !state.hasData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.hasError && !state.hasData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(homeControllerProvider.notifier).loadHomeData(),
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      );
    }

    final isNewUser = state.masteredWordCount == 0 && state.streakDays == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state.userName, l10n),
                const SizedBox(height: 20),
                _buildSectionTitle('学习主入口'),
                const SizedBox(height: 12),
                _buildPrimaryActions(context, l10n, isNewUser),
                const SizedBox(height: 24),
                _buildSectionTitle('复习模块'),
                const SizedBox(height: 12),
                _buildReviewSection(context, state),
                const SizedBox(height: 24),
                _buildSectionTitle('学习统计'),
                const SizedBox(height: 12),
                _buildStatsCard(context, state),
                const SizedBox(height: 24),
                _buildSectionTitle('工具区'),
                const SizedBox(height: 12),
                _buildToolsGrid(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String userName,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(l10n),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                userName.isNotEmpty
                    ? l10n.userGreeting(userName)
                    : l10n.homeWelcome,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeSubtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: 跳转设置页
          },
          icon: const Icon(Icons.settings_outlined),
          color: Colors.grey.shade800,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPrimaryActions(
    BuildContext context,
    AppLocalizations l10n,
    bool isNewUser,
  ) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionCard(
            title: '学习新单词',
            subtitle: isNewUser ? '开始学习你的第一个单词' : '继续探索新词，构建语义链条',
            colors: const [Color(0xFF5C8DFF), Color(0xFF6DD5ED)],
            icon: Icons.bolt_rounded,
            onTap: () => context.go('/initial-choice'),
            accentText: l10n.startLearning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActionCard(
            title: '学习五十音图',
            subtitle: '从基础发音开始打好根基',
            colors: const [Color(0xFF34D399), Color(0xFF0EA5E9)],
            icon: Icons.grid_view_rounded,
            onTap: () => context.push('/kana-chart'),
            accentText: '进入',
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(BuildContext context, HomeState state) {
    final wordReviewCount = state.reviewCount;
    const kanaReviewCount = 0; // 逻辑待接入

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReviewCard(
                title: '复习单词',
                count: wordReviewCount,
                description: wordReviewCount > 0
                    ? '今日待复习：$wordReviewCount 个单词'
                    : '还没有需要复习的单词',
                icon: Icons.refresh_rounded,
                color: const Color(0xFF2563EB),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReviewCard(
                title: '复习五十音',
                count: kanaReviewCount,
                description: kanaReviewCount > 0
                    ? '今日待复习：$kanaReviewCount 个假名'
                    : '还没有需要复习的假名',
                icon: Icons.translate_rounded,
                color: const Color(0xFF22C55E),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, HomeState state) {
    final isNewUser = state.masteredWordCount == 0 && state.streakDays == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日概览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                label: '今日学习',
                value: '${state.newWordCount}',
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFF6366F1),
              ),
              _StatTile(
                label: '今日复习',
                value: '${state.reviewCount}',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF14B8A6),
              ),
              _StatTile(
                label: '累计掌握',
                value: '${state.masteredWordCount}',
                icon: Icons.workspace_premium_outlined,
                color: const Color(0xFFF59E0B),
              ),
              _StatTile(
                label: '连续学习',
                value: '${state.streakDays} 天',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFEF4444),
              ),
              _StatTile(
                label: '今日时长',
                value: '${state.todayStudyDurationMinutes} 分钟',
                icon: Icons.timer_outlined,
                color: const Color(0xFF0EA5E9),
              ),
            ],
          ),
          if (isNewUser) ...[
            const SizedBox(height: 12),
            Text(
              '今天还没有开始学习，试着学一个新单词吧',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context, AppLocalizations l10n) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildToolCard(
          icon: Icons.book_outlined,
          title: l10n.wordBook,
          subtitle: l10n.wordBookSubtitle,
          color: Colors.amber,
          onTap: () {
            // TODO: 跳转到词库列表页
          },
        ),
        _buildToolCard(
          icon: Icons.bar_chart_rounded,
          title: l10n.detailedStats,
          subtitle: l10n.detailedStatsSubtitle,
          color: Colors.teal,
          onTap: () {
            // TODO: 跳转到统计详情页
          },
        ),
        _buildToolCard(
          icon: Icons.extension_rounded,
          title: '更多工具',
          subtitle: '预留未来功能',
          color: Colors.deepPurple,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    var hour = DateTime.now().hour;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;
  final String accentText;

  const _PrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.onTap,
    required this.accentText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  accentText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final int count;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.title,
    required this.count,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTodo = count > 0;
    final bgGradient = [
      color.withValues(alpha: 0.12),
      color.withValues(alpha: 0.04),
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: hasTodo
                                ? Colors.grey.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasTodo
                          ? color.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: hasTodo ? color : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
