import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../controller/home_controller.dart';
import '../state/home_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    _scheduleGreetingUpdate();
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  void _scheduleGreetingUpdate() {
    _greetingTimer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _greetingTimer = Timer(nextMinute.difference(now), () {
      if (!mounted) {
        return;
      }
      setState(() {});
      _scheduleGreetingUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final authDisplayName = ref.watch(displayNameProvider);
    final authUser = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!;
    final displayedUserName = _resolveDisplayedUserName(
      localUserName: state.userName,
      isLoggedIn: isLoggedIn,
      authDisplayName: authDisplayName,
      authEmail: authUser?.email,
    );

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

    final isNewUser = state.masteredWordCount == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () =>
                  ref.read(homeControllerProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, displayedUserName, l10n),
                    const SizedBox(height: 20),
                    _buildSectionTitle(l10n.homeSectionLearning),
                    const SizedBox(height: 12),
                    _buildPrimaryActions(context, l10n, isNewUser),
                    const SizedBox(height: 24),
                    _buildSectionTitle(l10n.homeSectionReview),
                    const SizedBox(height: 12),
                    _buildReviewSection(context, state, l10n),
                    const SizedBox(height: 24),
                    _buildSectionTitle(l10n.homeSectionTools),
                    const SizedBox(height: 12),
                    _buildToolsGrid(context, l10n),
                  ],
                ),
              ),
            ),
            if (state.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String displayedUserName,
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
                displayedUserName.isNotEmpty
                    ? l10n.userGreeting(displayedUserName)
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
            context.push('/settings');
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
    return Consumer(
      builder: (context, ref, _) {
        final selectedBookId = ref.watch(selectedBookIdProvider);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionCard(
                    title: l10n.homeKanaTitle,
                    subtitle: l10n.homeKanaSubtitle,
                    colors: const [Color(0xFF34D399), Color(0xFF0EA5E9)],
                    icon: Icons.grid_view_rounded,
                    onTap: () => context.push('/kana-chart'),
                    accentText: l10n.homeEnter,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PrimaryActionCard(
                    title: l10n.homeNewWordTitle,
                    subtitle: isNewUser
                        ? l10n.homeNewWordSubtitleNewUser
                        : l10n.homeNewWordSubtitle,
                    colors: const [Color(0xFF5C8DFF), Color(0xFF6DD5ED)],
                    icon: Icons.bolt_rounded,
                    onTap: () {
                      if (selectedBookId != null) {
                        context.push('/learn/$selectedBookId');
                      } else {
                        context.push('/book-selection');
                      }
                    },
                    accentText: l10n.startLearning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PrimaryActionCard(
              title: l10n.homeGrammarTitle,
              subtitle: l10n.homeGrammarSubtitle,
              colors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              icon: Icons.segment_rounded,
              onTap: () => context.push('/grammar/list'),
              accentText: l10n.homeGrammarAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewSection(
    BuildContext context,
    HomeState state,
    AppLocalizations l10n,
  ) {
    final wordReviewCount = state.reviewCount;
    final kanaReviewCount = state.kanaReviewCount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReviewCard(
                title: l10n.homeReviewWordTitle,
                count: wordReviewCount,
                description: wordReviewCount > 0
                    ? l10n.homeReviewWordCountDescription(wordReviewCount)
                    : l10n.homeReviewWordEmpty,
                icon: Icons.refresh_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => context.pushNamed('word-review'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReviewCard(
                title: l10n.homeReviewKanaTitle,
                count: kanaReviewCount,
                description: kanaReviewCount > 0
                    ? l10n.homeReviewKanaCountDescription(kanaReviewCount)
                    : l10n.homeReviewKanaEmpty,
                icon: Icons.translate_rounded,
                color: const Color(0xFF22C55E),
                onTap: () => context.pushNamed('kana-review'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolsGrid(BuildContext context, AppLocalizations l10n) {
    final tools = [
      _ToolItem(
        icon: Icons.book_outlined,
        title: l10n.wordBook,
        subtitle: l10n.wordBookSubtitle,
        gradient: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        onTap: () => context.push('/vocabulary-book'),
      ),
      _ToolItem(
        icon: Icons.format_quote_rounded,
        title: l10n.exampleFavoritesTitle,
        subtitle: l10n.homeExampleFavoritesSubtitle,
        gradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
        onTap: () => context.push('/example-favorites'),
      ),
      _ToolItem(
        icon: Icons.segment_rounded,
        title: l10n.homeGrammarBookTitle,
        subtitle: l10n.homeGrammarBookSubtitle,
        gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        onTap: () => context.push('/grammar-book'),
      ),
      _ToolItem(
        icon: Icons.menu_book_rounded,
        title: l10n.homeReadingTitle,
        subtitle: l10n.homeReadingSubtitle,
        gradient: const [Color(0xFFEC4899), Color(0xFFDB2777)],
        onTap: () => context.push('/article-list'),
      ),
      _ToolItem(
        icon: Icons.library_books_rounded,
        title: l10n.referenceTitle,
        subtitle: l10n.homeReferenceSubtitle,
        gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
        onTap: () => context.push('/reference'),
      ),
    ];

    return Container(
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
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            _buildToolRow(tools[i]),
            if (i < tools.length - 1)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: Colors.grey.shade100,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolRow(_ToolItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 渐变图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: item.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // 标题 + 副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  String _resolveDisplayedUserName({
    required String localUserName,
    required bool isLoggedIn,
    required String? authDisplayName,
    required String? authEmail,
  }) {
    if (!isLoggedIn) {
      return '';
    }

    final displayName = authDisplayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final normalizedLocalName = localUserName.trim();
    if (normalizedLocalName.isNotEmpty &&
        !_isGuestPlaceholderName(normalizedLocalName)) {
      return normalizedLocalName;
    }

    final email = authEmail?.trim() ?? '';
    if (email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return '';
  }

  bool _isGuestPlaceholderName(String value) {
    return value.isEmpty || value == 'BreezeJP User' || value == 'Breeze 用户';
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

/// 工具项数据
class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}
