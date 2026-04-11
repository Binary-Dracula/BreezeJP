import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../../../data/models/read/vocabulary_book_item.dart';
import '../controller/vocabulary_book_controller.dart';
import '../state/vocabulary_book_state.dart';

/// 单词本页面
class VocabularyBookPage extends ConsumerStatefulWidget {
  const VocabularyBookPage({super.key});

  @override
  ConsumerState<VocabularyBookPage> createState() => _VocabularyBookPageState();
}

class _VocabularyBookPageState extends ConsumerState<VocabularyBookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vocabularyBookControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref
          .read(vocabularyBookControllerProvider.notifier)
          .switchTab(_tabController.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabularyBookControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          // 搜索栏
          if (_isSearchVisible) _buildSearchBar(),
          // TabBar
          _buildTabBar(state),
          // 列表内容
          Expanded(child: _buildTabContent(state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(VocabularyBookState state) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        l10n.wordBook,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off : Icons.search,
            color: Colors.grey.shade800,
          ),
          onPressed: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _searchController.clear();
                ref.read(vocabularyBookControllerProvider.notifier).search('');
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '搜索单词、假名或释义...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(vocabularyBookControllerProvider.notifier)
                        .search('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        onChanged: (value) {
          ref.read(vocabularyBookControllerProvider.notifier).search(value);
        },
      ),
    );
  }

  Widget _buildTabBar(VocabularyBookState state) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF5C8DFF),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF5C8DFF),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: [
          Tab(text: l10n.vocabularyBookTabLearning(state.learningCount)),
          Tab(text: l10n.vocabularyBookTabMastered(state.masteredCount)),
          Tab(text: l10n.vocabularyBookTabIgnored(state.ignoredCount)),
        ],
      ),
    );
  }

  Widget _buildTabContent(VocabularyBookState state) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildWordList(
          items: state.learningWords,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          hasMore: state.hasMoreLearning,
          tabIndex: 0,
          emptyMessage: AppLocalizations.of(
            context,
          )!.vocabularyBookNoLearningWords,
        ),
        _buildWordList(
          items: state.masteredWords,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          hasMore: state.hasMoreMastered,
          tabIndex: 1,
          emptyMessage: AppLocalizations.of(
            context,
          )!.vocabularyBookNoMasteredWords,
          emptyIcon: Icons.emoji_events_outlined,
        ),
        _buildWordList(
          items: state.ignoredWords,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          hasMore: state.hasMoreIgnored,
          tabIndex: 2,
          emptyMessage: AppLocalizations.of(
            context,
          )!.vocabularyBookNoIgnoredWords,
          emptyIcon: Icons.visibility_off_outlined,
        ),
      ],
    );
  }

  Widget _buildWordList({
    required List<VocabularyBookItem> items,
    required bool isLoading,
    required bool isLoadingMore,
    required bool hasMore,
    required int tabIndex,
    required String emptyMessage,
    IconData emptyIcon = Icons.menu_book_outlined,
  }) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyIcon);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoadingMore) {
          ref.read(vocabularyBookControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _WordListTile(
            item: items[index],
            tabIndex: tabIndex,
            onTap: () {},
            onToggleStatus: () {
              ref
                  .read(vocabularyBookControllerProvider.notifier)
                  .toggleStatus(items[index].wordId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(AppLocalizations.of(context)!.goToLearn),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C8DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单词列表项
class _WordListTile extends StatelessWidget {
  final VocabularyBookItem item;
  final int tabIndex;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _WordListTile({
    required this.item,
    required this.tabIndex,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              // 音频按钮
              _buildAudioButton(),
              const SizedBox(width: 10),
              // 单词信息
              Expanded(child: _buildWordInfo()),
              // 状态切换按钮
              _buildStatusButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return Icon(
      item.hasAudio ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      size: 28,
      color: item.hasAudio ? const Color(0xFF5C8DFF) : Colors.grey.shade300,
    );
  }

  Widget _buildWordInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 单词 + 假名
        Row(
          children: [
            Flexible(
              child: Text(
                item.word,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.reading.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '(${item.reading})',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // 主释义
        if (item.primaryMeaning != null)
          Text(
            item.primaryMeaning!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 6),
        // 标签：JLPT + 词性
        Row(
          children: [
            if (item.jlptLevel != null)
              _buildTag(item.jlptLevel!, const Color(0xFF6366F1)),
            if (item.partOfSpeech != null) ...[
              const SizedBox(width: 6),
              _buildTag(item.partOfSpeech!, const Color(0xFF14B8A6)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (tabIndex == 0) {
      // 学习中 → 掌握
      return _StatusToggleButton(
        label: l10n.actionMaster,
        icon: Icons.check_circle_outline,
        color: const Color(0xFF34D399),
        onPressed: onToggleStatus,
      );
    } else if (tabIndex == 1) {
      // 已掌握 → 恢复学习
      return _StatusToggleButton(
        label: l10n.actionRestore,
        icon: Icons.replay_rounded,
        color: const Color(0xFF5C8DFF),
        onPressed: onToggleStatus,
      );
    } else {
      // 已忽略 → 恢复学习 (目前 toggleStatus 的 index == 2 会走默认逻辑，需在状态和控制器中确保正确)
      return _StatusToggleButton(
        label: l10n.actionRestore,
        icon: Icons.replay_rounded,
        color: const Color(0xFF5C8DFF),
        onPressed: onToggleStatus,
      );
    }
  }
}

/// 状态切换按钮
class _StatusToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _StatusToggleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
